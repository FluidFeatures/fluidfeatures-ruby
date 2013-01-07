require "logger"

require "fluidfeatures/config"

require "fluidfeatures/persistence/storage"
require "fluidfeatures/persistence/buckets"
require "fluidfeatures/persistence/features"

require "fluidfeatures/client"
require "fluidfeatures/app"

module FluidFeatures
  
  class << self
    attr_accessor :config
  end

  def self.app(config)
    config["logger"] ||= ::Logger.new(STDERR)
    self.config = config
    client = ::FluidFeatures::Client.new(config["baseuri"], config["logger"])
    ::FluidFeatures::App.new(client, config["appid"], config["secret"], config["logger"])
  end
end