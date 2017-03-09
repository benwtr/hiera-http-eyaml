require 'hiera/backend/eyaml/encryptor'
require 'hiera/backend/eyaml/utils'
require 'hiera/backend/eyaml/options'
require 'hiera/backend/eyaml/parser/parser'

class Hiera
  module Backend
    class Http_eyaml_backend

      def initialize
        debug("Hiera HTTP-eYAML backend starting")

        require 'lookup_http'
        @config = Config[:http_eyaml]

        lookup_supported_params = [
          :host,
          :port,
          :output,
          :failure,
          :ignore_404,
          :headers,
          :http_connect_timeout,
          :http_read_timeout,
          :use_ssl,
          :ssl_ca_cert,
          :ssl_cert,
          :ssl_key,
          :ssl_verify,
          :use_auth,
          :auth_user,
          :auth_pass,
        ]
        lookup_params = @config.select { |p| lookup_supported_params.include?(p) }

        @lookup = LookupHttp.new(lookup_params.merge( { :debug_log => "Hiera.debug" } ))


        @cache = {}
        @cache_timeout = @config[:cache_timeout] || 10
        @cache_clean_interval = @config[:cache_clean_interval] || 3600

        @regex_key_match = nil

        if confine_keys = @config[:confine_to_keys]
          confine_keys.map! { |r| Regexp.new(r) }
          @regex_key_match = Regexp.union(confine_keys)
        end

      end

      def lookup(key, scope, order_override, resolution_type)

        parse_eyaml_options(scope)

        debug("Looking up #{key} in HTTP-eYAML backend")

        require 'uri'

        # if confine_to_keys is configured, then only proceed if one of the
        # regexes matches the lookup key
        #
        if @regex_key_match
          return nil unless key[@regex_key_match] == key
        end


        answer = nil

        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        paths.insert(0, order_override) if order_override


        paths.each do |path|

          debug("Lookup #{key} from #{@config[:host]}:#{@config[:port]}#{path}")

          result = http_get_and_parse_with_cache(URI.escape(path))
          result = result[key] if result.is_a?(Hash)
          next if result.nil?

          parsed_result = parse_answer(result, scope)

          case resolution_type
          when :array
            answer ||= []
            answer << parsed_result
          when :hash
            answer ||= {}
            answer = Backend.merge_answer(parsed_result, answer)
          else
            answer = parsed_result
            break
          end
        end
        answer
      end


      private


      def debug(message)
        Hiera.debug("[hiera-http_eyaml_backend]: #{message}")
      end


      def http_get_and_parse_with_cache(path)
        return @lookup.get_parsed(path) if @cache_timeout <= 0

        now = Time.now.to_i
        expired_at = now + @cache_timeout

        # Deleting all stale cache entries can be expensive. Do not do it every time
        periodically_clean_cache(now) unless @cache_clean_interval == 0

        # Just refresh the entry being requested for performance
        if !@cache[path] || @cache[path][:expired_at] < now
          @cache[path] = {
            :expired_at => expired_at,
            :result => @lookup.get_parsed(path)
          }
        end
        @cache[path][:result]
      end


      def periodically_clean_cache(now)
        return if now < @clean_cache_at.to_i

        @clean_cache_at = now + @cache_clean_interval
        @cache.delete_if do |_, entry|
          entry[:expired_at] < now
        end
      end


      def decrypt(data)
        if encrypted?(data)
          debug("Attempting to decrypt")

          parser = Eyaml::Parser::ParserFactory.hiera_backend_parser
          tokens = parser.parse(data)
          decrypted = tokens.map{ |token| token.to_plain_text }
          plaintext = decrypted.join

          plaintext.chomp
        else
          data
        end
      end


      def encrypted?(data)
        /.*ENC\[.*?\]/ =~ data ? true : false
      end


      def parse_answer(data, scope, extra_data={})
        if data.is_a?(Numeric) or data.is_a?(TrueClass) or data.is_a?(FalseClass)
          return data
        elsif data.is_a?(String)
          return parse_string(data, scope, extra_data)
        elsif data.is_a?(Hash)
          answer = {}
          data.each_pair do |key, val|
            interpolated_key = Backend.parse_string(key, scope, extra_data)
            answer[interpolated_key] = parse_answer(val, scope, extra_data)
          end

          return answer
        elsif data.is_a?(Array)
          answer = []
          data.each do |item|
            answer << parse_answer(item, scope, extra_data)
          end

          return answer
        end
      end


      def parse_eyaml_options(scope)
        Config[:http_eyaml].each do |key, value|
          parsed_value = Backend.parse_string(value, scope)
          Eyaml::Options[key] = parsed_value
          debug("Set option: #{key} = #{parsed_value}")
        end

        Eyaml::Options[:source] = "hiera"
      end


      def parse_string(data, scope, extra_data={})
        decrypted_data = decrypt(data)
        Backend.parse_string(decrypted_data, scope, extra_data)
      end

    end
  end
end
