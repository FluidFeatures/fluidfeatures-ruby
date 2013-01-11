module FluidFeatures
  module ApiHelpers
    def config
      {
        "cache" => { "enable" => true, "dir" => "spec/tmp", "limit" => 1024 ** 2 },
        "base_uri" => "https://www.fluidfeatures.com/service",
        "app_id" => "1vu33ki6emqe3",
        "secret" => "secret",
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
