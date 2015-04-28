# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dblint/version'

Gem::Specification.new do |spec|
  spec.name          = 'dblint'
  spec.version       = Dblint::VERSION
  spec.authors       = ['Lukas Fittl']
  spec.email         = ['lukas@fittl.com']

  spec.summary       = 'Automatically tests your Rails app for common database query mistakes'
  spec.homepage      = 'https://github.com/lfittl/dblint'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', '>= 4.0'
  spec.add_runtime_dependency 'railties', '>= 4.0'
  spec.add_runtime_dependency 'pg'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'dotenv'
  spec.add_development_dependency 'rubocop', '~> 0.30'
  spec.add_development_dependency 'rubocop-rspec'
end
