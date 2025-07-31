class GlExporter
  class BaseSerializer
    extend Forwardable

    def initialize(options={})
      @model_url_service = options.fetch(:model_url_service) { ModelUrlService.new }
    end

    attr_reader :model_url_service
    def_delegator :model_url_service, :url_for_model

    # Serialize a given model into a hash that fits GitHub's gh-migrator schema
    #
    # @param [Hash] gl_model the GitLab model to be serialized
    # @return [Hash]
    # @example
    #   gitlab_project = Gitlab.project('kylemacey', 'repo-contrib-graph')
    #   GlExporter::RepositorySerializer.new.serialize(gitlab_project)
    def serialize(gl_model)
      self.gl_model = gl_model
      raise InvalidModelProvidedToSerializer unless valid?(gl_model)
      to_gh_hash
    end

    # Implements the serialization for the model
    #
    # @return [Hash]
    def to_gh_hash
      raise NotImplementedError, :to_gh_hash
    end

    # Some models require extra preparation before they can be serialized, such
    # as providition additional project information. This method is overwritten
    # by those subclasses.
    def valid?(gl_model)
      true
    end

    private

    attr_accessor :gl_model

    def format_timestamp(timestamp, date=false)
      return if timestamp.nil?
      time = Time.parse(timestamp).utc
      (date ? time.at_midnight : time).xmlschema
    end

    class InvalidModelProvidedToSerializer < StandardError;end;
  end
end
