
require "fluidfeatures/const"

module FluidFeatures
  class AppFeatureVersion
    
    attr_accessor :app, :feature_name, :version_name
    
    DEFAULT_VERSION_NAME = "default"
  
    def initialize(app, feature_name, version_name=DEFAULT_VERSION_NAME)

      raise "app invalid : #{app}" unless app.is_a? FluidFeatures::App
      raise "feature_name invalid : #{feature_name}" unless feature_name.is_a? String
      version_name ||= ::FluidFeatures::DEFAULT_VERSION_NAME
      raise "version_name invalid : #{version_name}" unless version_name.is_a? String

      @app = client
      @feature_name = feature_name
      @version_name = version_name

    end

    #
    # This can be used to control how much of your user-base sees a
    # particular feature. It may be easier to use the dashboard provided
    # at https://www.fluidfeatures.com/dashboard to manage this.
    #
    def set_enabled_percent(percent)

      unless percent.is_a? Numeric and percent >= 0.0 and percent <= 100.0
        raise "percent invalid : #{percent}"
      end

      app.put("/feature/#{feature_name}/#{version_name}/enabled/percent", {
        :enabled => {
          :percent => enabled_percent
        }
      })
    end

  end
end

