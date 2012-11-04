
require "fluidfeatures/app/user"
require "fluidfeatures/app/feature"
require "fluidfeatures/app/state"
require "fluidfeatures/app/reporter"

module FluidFeatures
  class App
    
    attr_accessor :client, :app_id, :secret, :state, :reporter, :logger
    
    def initialize(client, app_id, secret, logger)

      raise "client invalid : #{client}" unless client.is_a? FluidFeatures::Client
      raise "app_id invalid : #{app_id}" unless app_id.is_a? String
      raise "secret invalid : #{secret}" unless secret.is_a? String

      @client = client
      @app_id = app_id
      @secret = secret
      @logger = logger
      @state = ::FluidFeatures::AppState.new(self)
      @reporter = ::FluidFeatures::AppReporter.new(self)

    end

    def get(path, params=nil, cache=false)
      client.get("/app/#{app_id}#{path}", secret, params, cache)
    end

    def put(path, payload)
      client.put("/app/#{app_id}#{path}", secret, payload)
    end

    def post(path, payload)
      client.post("/app/#{app_id}#{path}", secret, payload)
    end

    #
    # Returns all the features that FluidFeatures knows about for
    # your application. The enabled percentage (how much of your user-base)
    # sees each feature is also provided.
    #
    def features
      get("/features")
    end

    def user(user_id, display_name, is_anonymous, unique_attrs, cohort_attrs)
      ::FluidFeatures::AppUser.new(self, user_id, display_name, is_anonymous, unique_attrs, cohort_attrs)
    end

    def user_transaction(user_id, url, display_name, is_anonymous, unique_attrs, cohort_attrs)
      user(user_id, display_name, is_anonymous, unique_attrs, cohort_attrs).transaction(url)
    end
    
    def feature_version(feature_name, version_name)
      ::FluidFeatures::AppFeatureVersion.new(self, feature_name, version_name)
    end

  end
end
