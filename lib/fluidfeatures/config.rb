
require 'yaml'
require 'fluidfeatures/exceptions'

module FluidFeatures
  class Config

    attr_accessor :vars

    def initialize(source, environment=nil)
      if source.is_a? String
        init_from_file(source, environment)
      elsif source.is_a? Hash
        init_from_hash(source)
      else
        raise FFeaturesConfigInvalid.new(
          "Invalid 'source' given. Expected file path String or Hash. Got #{source.class}"
        )
      end
      if @vars["cache"] and @vars["cache"]["limit"]
        @vars["cache"]["limit"] = self.class.parse_file_size(vars["cache"]["limit"])
      end
    end

    def [](name)
      @vars[name.to_s]
    end

    private

    def init_from_file path, environment
      unless File.exists? path
        raise FFeaturesConfigFileNotExists.new("File not found : #{path}")
      end
      environments = YAML.load_file path
      unless environments.is_a? Hash
        raise FFeaturesConfigInvalid.new("Config is invalid : #{path}")
      end
      @vars = (environments["common"] || {}).clone
      @vars.update environments[environment] if environments[environment]
    end

    def init_from_hash hash
      @vars = hash.clone
    end

    def self.parse_file_size(size)
      return size if size.is_a? Numeric
      return size.to_i if size.is_a? String and size.match /^\d+$/
      unless size.is_a? String and (/^(\d+)\s*(k|m|g)b$/i).match(size)
        raise FFeaturesConfigInvalid.new("Invalid file size string in config : '#{size}'")
      end
      $1.to_i * 1024 ** ("kmg".index($2.downcase) + 1)
    end

  end
end
