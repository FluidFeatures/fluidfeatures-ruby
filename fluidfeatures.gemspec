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
end
