
require "digest/sha1"
require "set"
require "thread"

require "fluidfeatures/const"
require "fluidfeatures/app/transaction"

module FluidFeatures
  class AppState
    
    attr_accessor :app
    USER_ID_NUMERIC = Regexp.compile("^\d+$")
    
    # Request to FluidFeatures API to long-poll for max
    # 30 seconds. The API may choose a different duration.
    # If not change in this time, API will return HTTP 304.
    ETAG_WAIT = ENV["FF_DEV"] ? 5 : 30

    # Hard max of 2 req/sec
    WAIT_BETWEEN_FETCH_SUCCESS = 0.5 # seconds

    # Hard max of 10 req/sec
    WAIT_BETWEEN_SEND_SUCCESS_NEXT_WAITING = 0.1 # seconds

    # If we are failing to communicate with the FluidFeautres API
    # then wait for this long between requests.
    WAIT_BETWEEN_FETCH_FAILURES = 5 # seconds

    def initialize(app)

      raise "app invalid : #{app}" unless app.is_a? FluidFeatures::App

      @app = app
      @features = {}
      @features_lock = ::Mutex.new

      run_state_fetcher

    end

    def features
      f = nil
      @features_lock.synchronize do
        f = @features
      end
      f
    end

    def features= f
      return unless f.is_a? Hash
      @features_lock.synchronize do
        @features = f
      end
    end

    def run_state_fetcher
      Thread.new do
        while true
          begin

            success, state = load_state

            # Note, success could be true, but state might be nil.
            # This occurs with 304 (no change)
            if success and state
              # switch out current state with new one
              self.features = state
            elsif not success
              # If service is down, then slow our requests
              # within this thread
              sleep WAIT_BETWEEN_FETCH_FAILURES
            end

            # What ever happens never make more than N requests
            # per second
            sleep WAIT_BETWEEN_FETCH_SUCCESS

          rescue Exception => err
            # catch errors, so that we do not affect the rest of the application
            app.logger.error "load_state failed : #{err.message}\n#{err.backtrace.join("\n")}"
            # hold off for a little while and try again
            sleep WAIT_BETWEEN_FETCH_FAILURES
          end
        end
      end
    end

    def load_state
      success, state = app.get("/features", { :verbose => true, :etag_wait => ETAG_WAIT }, true)
      if success and state
        state.each_pair do |feature_name, feature|
          feature["versions"].each_pair do |version_name, version|
            # convert parts to a Set for quick lookup
            version["parts"] = Set.new(version["parts"] || [])
          end
        end
      end
      return success, state
    end

    def feature_version_enabled_for_user(feature_name, version_name, user_id, user_attributes={})
      raise "feature_name invalid : #{feature_name}" unless feature_name.is_a? String
      version_name ||= ::FluidFeatures::DEFAULT_VERSION_NAME
      raise "version_name invalid : #{version_name}" unless version_name.is_a? String

      #assert(isinstance(user_id, basestring))
      
      user_attributes ||= {}
      user_attributes["user"] = user_id.to_s
      if user_id.is_a? Integer
        user_id_hash = user_id
      elsif USER_ID_NUMERIC.match(user_id)
        user_id_hash = user_id.to_i
      else
        user_id_hash = Digest::SHA1.hexdigest(user_id)[-10, 10].to_i(16)
      end
      enabled = false

      feature = features[feature_name]
      version = feature["versions"][version_name]
      modulus = user_id_hash % feature["num_parts"]
      enabled = version["parts"].include? modulus

      # check attributes
      feature["versions"].each_pair do |other_version_name, other_version|
        if other_version
          version_attributes = (other_version["enabled"] || {})["attributes"]
          if version_attributes
            user_attributes.each_pair do |attr_key, attr_id|
              version_attribute = version_attributes[attr_key.to_s]
              if version_attribute and version_attribute.include? attr_id.to_s
                if other_version_name == version_name
                  # explicitly enabled for this version
                  return true
                else
                  # explicitly enabled for another version
                  return false
                end
              end
            end
          end
        end
      end

      enabled
    end

  end
end
