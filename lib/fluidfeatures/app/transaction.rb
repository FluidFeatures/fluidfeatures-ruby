
require "fluidfeatures/const"

module FluidFeatures
  class AppUserTransaction
    
    attr_accessor :user, :url, :features, :start_time, :ended, :features_hit, :goals_hit, :unknown_features

    def initialize(user, url)

      @user = user
      @url  = url

      # take a snap-shot of the features end at
      # the beginning of the transactionapplication
      @features = user.features

      @features_hit = {}
      @goals_hit = {}
      @unknown_features = {}
      @start_time = Time.now
      @ended = false

    end

    def feature_enabled?(feature_name, version_name=nil, default_enabled=nil)
      raise "transaction ended" if ended
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
      raise "transaction ended" if ended
      unless @unknown_features.has_key? feature_name
        @unknown_features[feature_name] = {}
      end
      unless @unknown_features[feature_name].has_key? version_name
        @unknown_features[feature_name][version_name] = default_enabled
      end
    end

    def goal_hit(goal_name, goal_version_name=nil)
      raise "transaction ended" if ended
      raise "goal_name invalid : #{goal_name}" unless goal_name.is_a? String
      goal_version_name ||= ::FluidFeatures::DEFAULT_VERSION_NAME
      raise "goal_version_name invalid : #{goal_version_name}" unless goal_version_name.is_a? String
      @goals_hit[goal_name.to_s] ||= {}
      @goals_hit[goal_name.to_s][goal_version_name.to_s] = {}
    end

    def duration
      if ended
        @duration
      else
        Time.now - start_time
      end
    end

    #
    # This reports back to FluidFeatures which features we
    # encountered during this request, the request duration,
    # and statistics on time spent talking to the FluidFeatures
    # service. Any new features encountered will also be reported
    # back with the default_enabled status (see unknown_feature_hit)
    # so that FluidFeatures can auto-populate the dashboard.
    #
    def end_transaction
      raise "transaction ended" if ended
      @duration = duration #Time.now - start_time
      user.app.reporter.report_transaction(self)
      @ended = true
    end

  end
end