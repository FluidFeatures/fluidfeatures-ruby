
require "logger"

require "fluidfeatures/client"
require "fluidfeatures/app"

module FluidFeatures
  
  def self.app(base_uri, app_id, secret, logger=nil)
    logger ||= ::Logger.new(STDERR)
    client = ::FluidFeatures::Client.new(base_uri, logger)
    ::FluidFeatures::App.new(client, app_id, secret, logger)
  end

end