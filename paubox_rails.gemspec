# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'paubox_rails/version'

Gem::Specification.new do |spec|
  spec.name          = "paubox_rails"
  spec.version       = PauboxRails::VERSION
  spec.authors       = ["Jonathan Greeley"]
  spec.email         = ["jonathan@paubox.com"]

  spec.summary       = %q{Paubox Transactional Email API adapter for ActionMailer.'}
  spec.description   = %q{The Paubox Rails Gem integrates Paubox's Transactional Email HTTP API with ActionMailer.}
  spec.homepage      = "https://www.paubox.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency('actionmailer', ">= 4.0.0")
  spec.add_dependency('paubox', ">= 0.1.0")
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
end
