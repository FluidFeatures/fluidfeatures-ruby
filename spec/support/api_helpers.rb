module FluidFeatures
  module ApiHelpers
    def api_credentials
      [ ENV["FLUIDFEATURES_BASEURI"], ENV["FLUIDFEATURES_APPID"], ENV["FLUIDFEATURES_SECRET"] ]
    end

    def app
      @app ||= FluidFeatures.app(*api_credentials.push( Logger.new("/dev/null") ))
    end

    def transaction
      @transaction ||= app.user_transaction(nil, 'http://example.com', nil, true, [], [])
    end
    attr_writer :transaction

    def commit(transaction)
      transaction.end_transaction
      @transaction = transaction = nil
      #Thread.list.map &:join
    end

    #time to sleep waiting for thread
    def abit
      VCR.turned_on? ? 0 : 1.5
    end
  end
end
