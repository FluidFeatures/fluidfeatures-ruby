require "digest/sha1"
require "set"
require "thread"

require "fluidfeatures/const"
require "fluidfeatures/app/transaction"
require "fluidfeatures/exceptions"

module FluidFeatures
  class AppState

    attr_accessor :app

    USER_ID_NUMERIC = /^\d+$/

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
      raise "app invalid : #{app}" unless app.is_a? ::FluidFeatures::App
      @receiving = false
      configure(app)
    end

    def configure(app)
      @app = app
      @features = nil
      @features_lock = ::Mutex.new
    end

    def start_receiving
      return if @receiving
      @receiving = true
      run_loop
    end

    def stop_receiving(wait=false)
      @receiving = false
      if wait
        @loop_thread.join if @loop_thread and @loop_thread.alive?
      end
    end

    def features_storage
      @features_storage ||= FluidFeatures::Persistence::Features.create(FluidFeatures.config["cache"])
    end

    def features
      f = nil
      if @receiving
        # use features loaded in background
        features_lock_synchronize do
          f = @features
        end
      end
      unless f
        # we have not loaded features yet.
        # load in foreground but do not use caching (etags)
        success, state = load_state(use_cache=false)
        if success
          unless state
            # Since we did not use etag caching, state should never
            # be nil if success was true.
            raise FFeaturesAppStateLoadFailure.new("Unexpected nil state returned from successful load_state(use_cache=false).")
          end
          self.features = f = state
        else
          # fluidfeatures API must be down.
          # load persisted features from disk.
          self.features = f = features_storage.list
        end
      end
      # we should never return nil
      unless f
        # If we still could not load state then croak
        raise FFeaturesAppStateLoadFailure.new("Could not load features state from API: #{state}")
      end
      unless @receiving
        # start background receiver loop
        start_receiving
      end
      f
    end

    def features= f
      return unless f.is_a? Hash
      features_lock_synchronize do
        features_storage.replace(f)
        @features = f
      end
      f
    end

    def run_loop

      return unless @receiving
      return if @loop_thread and @loop_thread.alive?

      @loop_thread = Thread.new do
        while @receiving
          run_loop_iteration(WAIT_BETWEEN_FETCH_SUCCESS, WAIT_BETWEEN_FETCH_FAILURES)
        end
      end
    end

    def run_loop_iteration(wait_between_fetch_success, wait_between_fetch_failures)
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
          sleep wait_between_fetch_failures
        end

        # What ever happens never make more than N requests
        # per second
        sleep wait_between_fetch_success

      rescue Exception => err
        # catch errors, so that we do not affect the rest of the application
        app.logger.error "load_state failed : #{err.message}\n#{err.backtrace.join("\n")}"
        # hold off for a little while and try again
        sleep wait_between_fetch_failures
      end
    end

    def load_state(use_cache=true)
      success, state = app.get("/features", { :verbose => true, :etag_wait => ETAG_WAIT }, use_cache)
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
      return false unless feature
      version = feature["versions"][version_name]
      return false unless version

      modulus = ((user_id_hash - 1) % feature["num_parts"]) + 1
      enabled = version["parts"].include? modulus

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

    @private
    def features_lock_synchronize
      @features_lock.synchronize do
        yield
      end
    end

  end
end
