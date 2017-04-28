# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hiera/backend/http_eyaml.rb'

Gem::Specification.new do |spec|
  spec.name          = "hiera-http-eyaml"
  spec.version       = Hiera::Backend::Http_eyaml::VERSION
  spec.authors       = ["craig@craigdunn.org", "benwtr"]
  spec.email         = ["ben@g.megatron.org"]

  spec.summary       = 'hiera-http-eyaml'
  spec.description   = %q{Fork of the Hiera HTTP backend with eYAML support}
  spec.homepage      = "https://github.com/benwtr/hiera-http-eyaml"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency('hiera-eyaml', '~>2.1.0')
  spec.add_dependency('lookup_http', '>=1.0.0')
end
