require "fluidfeatures/const"
require "thread"

module FluidFeatures
  class AppReporter
    
    attr_accessor :app
    
    # Throw oldest buckets away or offload to persistent storage when this limit reached.
    MAX_BUCKETS = 10

    # Max number of transactions we queue in a bucket.
    MAX_BUCKET_SIZE = 100

    # While queue is empty we will check size every 0.5 secs
    WAIT_BETWEEN_QUEUE_EMTPY_CHECKS = 0.5 # seconds

    # Soft max of 1 req/sec
    WAIT_BETWEEN_SEND_SUCCESS_NONE_WAITING = 1 # seconds

    # Hard max of 10 req/sec
    WAIT_BETWEEN_SEND_SUCCESS_NEXT_WAITING = 0.1 # seconds

    # If we are failing to communicate with the FluidFeautres API
    # then wait for this long between requests.
    WAIT_BETWEEN_SEND_FAILURES = 5 # seconds
    
    def initialize(app)
      raise "app invalid : #{app}" unless app.is_a? ::FluidFeatures::App
      @started_sending = false
      configure(app)
      at_exit do
        buckets_storage.append(@buckets)
      end
    end

    def start_sending
      return if @started_sending
      @started_sending = true
      run_loop
    end

    def buckets_storage
      @buckets_storage ||= FluidFeatures::Persistence::Buckets.create(FluidFeatures.config["cache"])
    end

    def features_storage
      @features_storage ||= FluidFeatures::Persistence::Features.create(FluidFeatures.config["cache"])
    end

    def configure(app)
      @app = app

      @buckets = buckets_storage.fetch(MAX_BUCKETS)

      @buckets_lock = ::Mutex.new

      #maybe could get rid of @current_bucket concept
      @current_bucket = nil
      @current_bucket_lock = ::Mutex.new
      @current_bucket = last_or_new_bucket

      @unknown_features = features_storage.list_unknown
      @unknown_features_lock = ::Mutex.new
    end

    def last_or_new_bucket
      @buckets.empty? || @buckets.last.size >= MAX_BUCKET_SIZE ? new_bucket : @buckets.last
    end

    # Pass FluidFeatures::AppUserTransaction for reporting
    # back to the FluidFeatures service.
    def report_transaction(transaction)

      user = transaction.user

      payload = {
        :url => transaction.url,
        :user => {
          :id => user.unique_id
        },
        :hits => {
          :feature => transaction.features_hit,
          :goal    => transaction.goals_hit
        },
        # stats
        :stats => {
          :duration => transaction.duration
        }
      }

      payload_user = payload[:user] ||= {}
      payload_user[:name] = user.display_name if user.display_name
      payload_user[:anonymous] = user.anonymous if user.anonymous
      payload_user[:unique] = user.unique_attrs if user.unique_attrs
      payload_user[:cohorts] = user.cohort_attrs if user.cohort_attrs

      queue_transaction_payload(payload)

      if transaction.unknown_features.size > 0
        queue_unknown_features(transaction.unknown_features)
        features_storage.replace_unknown(@unknown_features)
      end

      start_sending unless @started_sending
    end

    def run_loop
      Thread.new do
        while true
          begin

            unless transactions_queued?
              sleep WAIT_BETWEEN_QUEUE_EMTPY_CHECKS
              next
            end

            success = send_transactions

            if success
              # Unless we have a full bucket waiting do not make
              # more than N requests per second.
              if bucket_count <= 1
                sleep WAIT_BETWEEN_SEND_SUCCESS_NONE_WAITING
              else
                sleep WAIT_BETWEEN_SEND_SUCCESS_NEXT_WAITING
              end
            else  
              # If service is down, then slow our requests
              # within this thread
              sleep WAIT_BETWEEN_SEND_FAILURES
            end

          rescue Exception => err
            # catch errors, so that we do not affect the rest of the application
            app.logger.error "[FF] send_transactions failed : #{err.message}\n#{err.backtrace.join("\n")}"
            # hold off for a little while and try again
            sleep WAIT_BETWEEN_SEND_FAILURES
          end
        end
      end
    end

    @private
    def transactions_queued?
      have_transactions = false
      buckets_lock_synchronize do
        if @buckets.size == 1
          @current_bucket_lock.synchronize do
            if @current_bucket.size > 0
              have_transactions = true
            end
          end
        elsif @buckets.size > 1 and @buckets[0].size > 0
          have_transactions = true
        end
      end
      have_transactions
    end

    @private
    def send_transactions
      bucket = remove_bucket

      # Take existing unknown features and reset
      unknown_features = nil
      @unknown_features_lock.synchronize do
        unknown_features = @unknown_features
        @unknown_features = {}
      end

      remaining_buckets_stats = nil
      buckets_lock_synchronize do
        remaining_buckets_stats = @buckets.map { |b| b.size }
      end

      api_request_log = app.client.siphon_api_request_log

      payload = {
        :client_uuid => app.client.uuid,
        :transactions => bucket,
        :stats => {
          :waiting_buckets => remaining_buckets_stats
        },
        :unknown_features => unknown_features,
        :api_request_log => api_request_log
      }

      if remaining_buckets_stats.size > 0
        payload[:stats][:waiting_buckets] = remaining_buckets_stats
      end

      # attempt to send to fluidfeatures service
      success = app.post("/report/transactions", payload)

      # handle failure to send data
      unless success
        # return bucket into bucket queue until the next attempt at sending
        if not unremove_bucket(bucket)
          app.logger.warn "[FF] Discarded transactions due to reporter backlog. These will not be reported to FluidFeatures."
        end
        # return unknown features to queue until the next attempt at sending
        queue_unknown_features(unknown_features)
      else
        features_storage.replace_unknown({})
      end

      # return whether we were able to send or not
      success
    end

    @private
    def bucket_count
      num_buckets = 0
      buckets_lock_synchronize do
        num_buckets = @buckets.size
      end
      num_buckets
    end
      
    @private
    def new_bucket
      bucket = []
      buckets_lock_synchronize do
        @buckets << bucket
        if @buckets.size > MAX_BUCKETS
          #offload to storage
          unless buckets_storage.append_one(@buckets.shift)
            app.logger.warn "[FF] Discarded transactions due to reporter backlog. These will not be reported to FluidFeatures."
          end
        end
      end
      bucket
    end

    @private
    def remove_bucket
      removed_bucket = nil
      buckets_lock_synchronize do
        #try to get buckets from storage first
        if @buckets.empty? && !buckets_storage.empty?
          @buckets = buckets_storage.fetch(MAX_BUCKETS)
        end

        if @buckets.size > 0
          removed_bucket = @buckets.shift
        end
        if @buckets.size == 0
          @current_bucket_lock.synchronize do
            @current_bucket = []
            @buckets << @current_bucket
          end
        end
      end
      removed_bucket
    end

    @private
    def unremove_bucket(bucket)
      success = false
      buckets_lock_synchronize do
        if @buckets.size <= MAX_BUCKETS
          @buckets.unshift bucket
          success = true
        else
          success = buckets_storage.append_one(bucket)
        end
      end
      success
    end

    @private
    def queue_transaction_payload(transaction_payload)
      @current_bucket_lock.synchronize do
        if @current_bucket.size >= MAX_BUCKET_SIZE
          @current_bucket = new_bucket
        end
        @current_bucket << transaction_payload
      end
    end

    @private
    def queue_unknown_features(unknown_features)
      raise "unknown_features should be a Hash" unless unknown_features.is_a? Hash
      unknown_features.each_pair do |feature_name, versions|
        raise "unknown_features values should be a Hash. versions=#{versions}" unless versions.is_a? Hash
      end
      @unknown_features_lock.synchronize do
        unknown_features.each_pair do |feature_name, versions|
          unless @unknown_features.has_key? feature_name
            @unknown_features[feature_name] = {}
          end
          versions.each_pair do |version_name, default_enabled|
            unless @unknown_features[feature_name].has_key? version_name
              @unknown_features[feature_name][version_name] = default_enabled
            end
          end
        end
      end
    end

    @private
    def buckets_lock_synchronize
      @buckets_lock.synchronize do
        yield
      end
    end

  end
end
