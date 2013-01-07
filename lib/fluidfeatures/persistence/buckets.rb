module FluidFeatures
  module Persistence
    class Buckets < Storage
      attr_accessor :limit

      def self.create(config)
        return NullBuckets.new unless config && config["dir"] && config["enable"] && config["limit"] > 0
        new(config)
      end

      def initialize(config)
        self.limit = config["limit"]
        super config
      end

      def fetch(n = 1)
        ret = []
        store.transaction do
          return [] unless store && store["buckets"] && !store["buckets"].empty?
          n = store["buckets"].size if n > store["buckets"].size
          ret = store["buckets"].slice!(0, n)
          store.commit
        end
        return ret
      end

      def append(buckets)
        transaction do
          store["buckets"] += buckets
        end
      end

      def append_one(bucket)
        transaction do
          store["buckets"].push(bucket)
        end
      end

      def empty?
        store.transaction(true) do
          return true unless store["buckets"]
          return store["buckets"].empty?
        end
      end

      private

      def transaction
        begin
          return false if file_size > limit
          store.transaction do
            store["buckets"] ||= []
            yield
          end
        rescue Exception => _
          return false
        end
      end
    end

    class NullBuckets
      def fetch(*args); [] end

      def append(*args); false end

      def append_one(*args); false end

      def empty?; true end
    end
  end
end
