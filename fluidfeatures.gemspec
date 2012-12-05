# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fluidfeatures/version"

Gem::Specification.new do |s|
  s.name        = "fluidfeatures"
  s.version     = FluidFeatures::VERSION
  s.authors     = ["Phil Whelan"]
  s.email       = ["phil@fluidfeatures.com"]
  s.homepage    = "https://github.com/FluidFeatures/fluidfeatures-ruby"
  s.summary     = %q{Ruby client for the FluidFeatures service.}
  s.description = %q{Ruby client for the FluidFeatures service.}
  s.rubyforge_project = s.name
  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
  s.add_dependency "persistent_http", "~>1.0.3"
  s.add_dependency "uuid", "~>2.3.5"

  s.add_development_dependency('rake', '~> 10.0.2')
  s.add_development_dependency('rspec', '~> 2.12.0')
  s.add_development_dependency('guard-rspec', '~> 2.2.1')
  s.add_development_dependency('rb-inotify', '~> 0.8.8')
  s.add_development_dependency('vcr', '~> 2.3.0')
  s.add_development_dependency('fakeweb', '~> 1.3.0')
end
