require "pstore"

module FluidFeatures
  module Persistence
    class Storage
      attr_accessor :dir, :file_name, :store, :logger

      def initialize(config, logger=nil)
        @dir = config["dir"]
        @logger = logger || Logger.new(STDERR)
        @file_name = "#{self.class.to_s.split('::').last.downcase}.pstore"
        FileUtils.mkpath(dir) unless Dir.exists?(dir)
      end

      def store
        @store ||= PStore.new(path, true)
      end

      def path
        File.join(dir, file_name)
      end

      def file_size
        # TODO: rescue should return nil here
        File.size(path) rescue 0
      end
    end
  end
end
