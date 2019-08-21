# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'push_kit/apns/constants'

Gem::Specification.new do |spec|
  spec.name          = 'push_kit-apns'
  spec.version       = PushKit::APNS::VERSION
  spec.authors       = ['Nialto Services']
  spec.email         = ['support@nialtoservices.co.uk']

  spec.summary       = 'Send APNS push notifications with ease'
  spec.homepage      = 'https://github.com/nialtoservices/push_kit-apns'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.metadata['yard.run'] = 'yri'

  spec.add_dependency 'concurrent-ruby', '~> 1.1', '>= 1.1.5'
  spec.add_dependency 'http-2',          '~> 0.10.1'
  spec.add_dependency 'jwt',             '~> 2.2'

  spec.add_development_dependency 'bundler',     '~> 2.0'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'rake',        '~> 12.3'
  spec.add_development_dependency 'rspec',       '~> 3.8'
  spec.add_development_dependency 'yard',        '~> 0.9.20'
end
