module FluidFeatures
  class Config
    attr_accessor :vars
    def initialize(path, environment, replacements = {})
      self.vars = YAML.load(ERB.new(File.read(path)).result)
      self.vars = vars["common"].update(vars[environment])
      self.vars = vars.update(replacements)
      self.vars["cache"]["limit"] = self.class.parse_file_size(vars["cache"]["limit"]) if vars["cache"]
    end

    def [](name)
      @vars[name.to_s]
    end

    def self.parse_file_size(size)
      return size if !size || size.is_a?(Numeric) || !/(\d+)\s*(kb|mb|gb)$/.match(size.downcase)
      $1.to_i * 1024 ** (%w{kb mb gb}.index($2) + 1)
    end
  end
end
