class GlExporter
  class MigratableResource

    attr_reader :attributes, :target_url

    # Instantiate a new MigratableResource and add it to MigratableResources
    #
    # @param [String] model_name the type of model to be added
    # @param [Hash] attributes the attributes for the migratable resource
    # @option attributes [Hash] :model a GitLab model to be stored
    # @option attributes [String] :source_url the URL of the model before any
    #   rewrites
    # @option attributes [String] :created_at
    # @return [MigratableResource]
    def self.create(model_name, attributes)
      new(attributes).tap do |instance|
        instance.attributes[:model_name] = model_name
        storage.store(model_name, instance)
      end
    end

    # Return all MigratableResources
    #
    # @return [Array]
    def self.all
      storage.data.flat_map { |k, v| v }
    end

    # Return all MigratableResources of a certain type or types
    #
    # @param [List] types one or more types of models to return
    # @return [Array]
    def self.by_type(*types)
      storage.data.slice(*types).flat_map { |k, v| v }
    end

    # Given a starting url, return the rewritten url for a model
    #
    # @param [String] source_url the URL before it is rewritten
    # @return [String] the rewritten URL
    def self.target_url_from_source_url(source_url)
      record = all.detect { |mr| mr.source_url == source_url }
      record && record.target_url
    end

    # Find a MigratableResource by id
    #
    # @param [String] model_name the type of model to find
    # @param [Integer] id the id of the model to find
    # @return [MigratableResource]
    def self.find(model_name, id)
      storage.detect(model_name) { |mr| mr.model["id"] == id }
    end

   # Find a MigratableResource by any attribute
   #
   # @param [String] model_name the type of model to find
   # @param [String] attribute the name of the attribute to search by
   # @param [String] val the value of the attribute to search by
   # @return [MigratableResource]
    def self.find_by(model_name, attribute, val)
      storage.detect(model_name) { |mr| mr.model[attribute] == val }
    end

    # Delete all MigratableResources or just those of a certain type if
    # `model_name` is provided
    #
    # @param [String] model_name the type of model to delete
    def self.purge!(model_name)
      storage.purge!(model_name)
    end

    def self.storage
      Storage.instance
    end

    def initialize(attributes)
      @attributes = attributes
    end

    def model_name
      attributes[:model_name]
    end

    def source_url
      attributes[:source_url]
    end

    def target_url=(target_url)
      @target_url = target_url
    end

    def model
      attributes[:model]
    end

    def created_at
      Time.parse(attributes[:created_at])
    end
  end
end
