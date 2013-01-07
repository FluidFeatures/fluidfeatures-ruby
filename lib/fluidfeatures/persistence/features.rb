module FluidFeatures
  module Persistence
    class Features < Storage

      def self.create(config)
        return NullFeatures.new unless config && config["dir"] && config["enable"]
        new(config)
      end

      def initialize(config)
        super config
      end

      def list
        store.transaction(true) do
          return {} unless store && store["features"]
          store["features"]
        end
      end

      def replace(features)
        transaction do
          store["features"] = features
          !!store["features"]
        end
      end

      def list_unknown
        store.transaction(true) do
          return {} unless store && store["unknown_features"]
          store["unknown_features"]
        end
      end

      def replace_unknown(features)
        transaction do
          store["unknown_features"] = features
          !!store["unknown_features"]
        end
      end

      private

      def transaction
        begin
          store.transaction do
            yield
          end
        rescue Exception => _
          return false
        end
      end
    end

    class NullFeatures
      def list; {} end
      def list_unknown; {} end
      def replace(*args); false end
      def replace_unknown(*args); false end
    end
  end
end
