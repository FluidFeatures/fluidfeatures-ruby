
require "fluidfeatures/const"
require "fluidfeatures/app/transaction"

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

    def get(path, params=nil)
      app.get("/user/#{unique_id}#{path}", params)
    end

    def post(path, payload)
      app.post("/user/#{unique_id}#{path}", payload)
    end

    #
    # Returns all the features enabled for a specific user.
    # This will depend on the user's unique_id and how many
    # users each feature is enabled for.
    #
    def features

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

      if true
        features_enabled = get("/features", attribute_ids) || {}
      else
        features_enabled = {}
        app.state.features.each do |feature_name, feature|
          feature["versions"].keys.each do |version_name|
            features_enabled[feature_name] ||= {}
            features_enabled[feature_name][version_name] = \
              app.state.feature_version_enabled_for_user(
                feature_name,
                version_name,
                unique_id,
                attribute_ids
              )
          end
        end
      end
      features_enabled
    end

    def transaction(url)
      ::FluidFeatures::AppUserTransaction.new(self, url)
    end

  end
end
