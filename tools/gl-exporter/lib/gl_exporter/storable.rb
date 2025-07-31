class GlExporter
  module Storable

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end
    
    # Save a GitLab model to memory to be rewritten or serialized later
    #
    # @param [String] model_name the type of model that will be stored
    # @param [String] model the model to be stored
    # @return [MigratableResource]
    def store(model_name, model)
      MigratableResource.create(model_name,
        :source_url => model_url_service.url_for_model(model, type: model_name),
        :model => model,
        :created_at => model["created_at"]
      )
    end
  end
end
