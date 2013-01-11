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

  def self.app(config, logger=nil)
    logger ||= ::Logger.new(STDERR)
    self.config = config
    client = ::FluidFeatures::Client.new(config["base_uri"], logger)
    ::FluidFeatures::App.new(client, config["app_id"], config["secret"], logger)
  end
end
