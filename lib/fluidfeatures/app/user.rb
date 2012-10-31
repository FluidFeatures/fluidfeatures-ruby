
require "fluidfeatures/const"

module FluidFeatures
  class AppUser
    
    attr_accessor :app, :unique_id, :display_name, :anonymous, :unique_attrs, :cohort_attrs
    
    def initialize(app, user_id, display_name, is_anonymous, unique_attrs, cohort_attrs)

      raise "app invalid : #{app}" unless app.is_a? FluidFeatures::App

      @app = app
      @unique_id = user_id
      @display_name = display_name
      @anonymous = is_anonymous
      @unique_attrs = unique_attrs
      @cohort_attrs = cohort_attrs

      @features = nil
      @features_hit = {}
      @goals_hit = {}
      @unknown_features = {}

      if not unique_id or is_anonymous

        # We're an anonymous user
        @anonymous = true

        # if we were not given a user[:id] for this anonymous user, then get
        # it from an existing cookie or create a new one.
        unless unique_id
          # Create new unique id (for cookie). Use rand + micro-seconds of current time
          @unique_id = "anon-" + Random.rand(9999999999).to_s + "-" + ((Time.now.to_f * 1000000).to_i % 1000000).to_s
        end
      end

    end

    #
    # Returns all the features enabled for a specific user.
    # This will depend on the user's unique_id and how many
    # users each feature is enabled for.
    #
    def load_features

      # extract just attribute ids into simple hash
      attribute_ids = {
        :anonymous => anonymous
      }
      [unique_attrs, cohort_attrs].each do |attrs|
        if attrs
          attrs.each do |attr_key, attr|
            if attr.is_a? Hash
              if attr.has_key? :id
                attribute_ids[attr_key] = attr[:id]
              end
            else
              attribute_ids[attr_key] = attr
            end
          end
        end
      end

      # normalize attributes ids as strings
      attribute_ids.each do |attr_key, attr_id|
        if attr_id.is_a? FalseClass or attr_id.is_a? TrueClass
          attribute_ids[attr_key] = attr_id.to_s.downcase
        elsif not attr_id.is_a? String
          attribute_ids[attr_key] = attr_id.to_s
        end
      end

      app.get("/user/#{unique_id}/features", attribute_ids) || {}
    end

    def features
      @features ||= load_features
    end

    def feature_enabled?(feature_name, version_name, default_enabled)

      raise "feature_name invalid : #{feature_name}" unless feature_name.is_a? String
      version_name ||= ::FluidFeatures::DEFAULT_VERSION_NAME

      if features.has_key? feature_name
        feature = features[feature_name]
        if feature.is_a? Hash
          if feature.has_key? version_name
            enabled = feature[version_name]
          end
        end
      end

      if enabled === nil
        enabled = default_enabled
        
        # Tell FluidFeatures about this amazing new feature...
        unknown_feature_hit(feature_name, version_name, default_enabled)
      end

      if enabled
        @features_hit[feature_name] ||= {}
        @features_hit[feature_name][version_name.to_s] = {}
      end

      enabled
    end

    #
    # This is called when we encounter a feature_name that
    # FluidFeatures has no record of for your application.
    # This will be reported back to the FluidFeatures service so
    # that it can populate your dashboard with this feature.
    # The parameter "default_enabled" is a boolean that says whether
    # this feature should be enabled to all users or no users.
    # Usually, this is "true" for existing features that you are
    # planning to phase out and "false" for new feature that you
    # intend to phase in.
    #
    def unknown_feature_hit(feature_name, version_name, default_enabled)
      if not @unknown_features[feature_name]
        @unknown_features[feature_name] = { :versions => {} }
      end
      @unknown_features[feature_name][:versions][version_name] = default_enabled
    end

    def goal_hit(goal_name, goal_version_name)
      sleep 10
      raise "goal_name invalid : #{goal_name}" unless goal_name.is_a? String
      goal_version_name ||= ::FluidFeatures::DEFAULT_VERSION_NAME
      raise "goal_version_name invalid : #{goal_version_name}" unless goal_version_name.is_a? String
      @goals_hit[goal_name.to_s] ||= {}
      @goals_hit[goal_name.to_s][goal_version_name.to_s] = {}
    end

    #
    # This reports back to FluidFeatures which features we
    # encountered during this request, the request duration,
    # and statistics on time spent talking to the FluidFeatures
    # service. Any new features encountered will also be reported
    # back with the default_enabled status (see unknown_feature_hit)
    # so that FluidFeatures can auto-populate the dashboard.
    #
    def end_transaction(url, stats)

      payload = {
        :url => url,
        :user => {
          :id => unique_id
        },
        :hits => {
          :feature => @features_hit,
          :goal    => @goals_hit
        }
      }

      if stats
        raise "stats invalid : #{stats}" unless stats.is_a? Hash
        payload[:stats] = stats
      end

      payload_user = payload[:user] ||= {}
      payload_user[:name] = display_name if display_name
      payload_user[:anonymous] = anonymous if anonymous
      payload_user[:unique] = unique_attrs if unique_attrs
      payload_user[:cohorts] = cohort_attrs if cohort_attrs
      
      (payload[:stats] ||= {})[:ff_latency] = app.client.last_fetch_duration
      if @unknown_features.size
        (payload[:features] ||= {})[:unknown] = @unknown_features
        @unknown_features = {}
      end
      
      app.post("/user/#{unique_id}/features/hit", payload)

    end

  end
end
