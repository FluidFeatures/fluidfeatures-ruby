
require "digest/sha1"
require "set"

require "fluidfeatures/const"
require "fluidfeatures/app/transaction"

module FluidFeatures
  class AppState
    
    attr_accessor :app, :features
    USER_ID_NUMERIC = Regexp.compile("^\d+$")
    
    def initialize(app)

      raise "app invalid : #{app}" unless app.is_a? FluidFeatures::App

      @app = app

      load_state

    end

    def load_state
      result = app.get("/features", { :verbose => true })
      result.each do |feature_name, feature|
        feature["versions"].each do |version_name, version|
          # convert parts to a Set for quick lookup
          version["parts"] = Set.new(version["parts"] || [])
        end
      end
      @features = result
    end

    def feature_version_enabled_for_user(feature_name, version_name, user_id, user_attributes={})
      raise "feature_name invalid : #{feature_name}" unless feature_name.is_a? String
      version_name ||= ::FluidFeatures::DEFAULT_VERSION_NAME
      raise "version_name invalid : #{version_name}" unless version_name.is_a? String

      #assert(isinstance(user_id, basestring))
      
      user_attributes ||= {}
      user_attributes["user"] = user_id
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
      feature["versions"].each do |other_version_name, other_version|
        if other_version
          version_attributes = (other_version["enabled"] || {})["attributes"]
          if version_attributes
            user_attributes.each do |attr_key, attr_id|
              version_attribute = version_attributes[attr_key]
              if version_attribute and version_attribute.include? attr_id
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
