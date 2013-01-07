module FluidFeatures
  module ApiHelpers
    def config
      {
        "cache" => { "enable" => true, "dir" => "spec/tmp", "limit" => 1024 ** 2 },
        "baseuri" => ENV["FLUIDFEATURES_BASEURI"],
        "appid" => ENV["FLUIDFEATURES_APPID"],
        "secret" => ENV["FLUIDFEATURES_SECRET"],
        "logger" => Logger.new("/dev/null")
      }
    end

    def app
      @app ||= FluidFeatures.app(config)
    end

    def transaction
      @transaction ||= app.user_transaction(nil, 'http://example.com', nil, true, [], [])
    end
    attr_writer :transaction

    def commit(transaction)
      transaction.end_transaction
      @transaction = transaction = nil
    end

    #time to sleep waiting for thread
    def abit
      VCR.turned_on? ? 0 : 1.5
    end
  end
end
