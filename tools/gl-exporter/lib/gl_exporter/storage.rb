require "singleton"

class GlExporter
  class Storage
    include Singleton

    attr_accessor :data

    def initialize
      self.data = {}
    end

    def store(collection_name, *input_data)
      collection(collection_name).push(*input_data)
    end

    def all(collection_name)
      collection(collection_name)
    end

    def purge!(collection_name)
      data.delete(collection_name)
    end

    def detect(collection_name, &block)
      collection(collection_name).detect(&block)
    end

    def self.drop!
      instance.data = {}
    end

    private

    def collection(collection_name)
      data[collection_name.to_s] ||= []
      data[collection_name.to_s]
    end
  end
end
