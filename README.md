# Hiera HTTP+eYAML Backend

This is a fork of the hiera-http backend that decrypts hiera-eyaml blobs.

- https://github.com/crayfishx/hiera-http/
- https://github.com/voxpupuli/hiera-eyaml/

## Configuration

The configuration is the same as hiera-http's configuration, plus any
hiera-eyaml encryption options; at minimum you will need to set
`pkcs7_private_key` and `pkcs7_public_key`.

An example configuration for Hiera 3:

```
---
:backends:
  - http_eyaml

:http_eyaml:
  :host: 127.0.0.1
  :port: 5984
  :output: json
  :cache_timeout: 10
  :pkcs7_private_key: /path/to/private_key.pkcs7.pem
  :pkcs7_public_key:  /path/to/public_key.pkcs7.pem
  :headers:
    :X-Token: my-token
  :paths:
    - /configuration/%{fqdn}
    - /configuration/%{env}
    - /configuration/common
```

## Installation

Add this line to your puppet repo's Gemfile:

```ruby
gem 'hiera-http-eyaml'
```

Or install it with gem:

    $ gem install hiera-http-eyaml

