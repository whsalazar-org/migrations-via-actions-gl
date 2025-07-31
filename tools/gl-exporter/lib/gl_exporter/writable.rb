class GlExporter
  module Writable
    # A mapping of models to their serializers
    Serializers = {
      "attachment"       => AttachmentSerializer,
      "user"             => UserSerializer,
      "organization"     => OrganizationSerializer,
      "milestone"        => MilestoneSerializer,
      "repository"       => RepositorySerializer,
      "commit_comment"   => CommitCommentSerializer,
      "issue"            => IssueSerializer,
      "issue_comment"    => IssueCommentSerializer,
      "pull_request"     => PullRequestSerializer,
      "release"          => ReleaseSerializer,
      "protected_branch" => ProtectedBranchSerializer
    }

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end

    # Serialize a model with a given type
    #
    # @param [String] model_name the type of model to be serialized
    # @param [Hash] model the GitLab data to be serialized
    # @return [Boolean] when true, this is the first time this model has been
    #   serialized; when false, this model has been serialized before so it was
    #   not serialized again
    def serialize(model_name, model)
      serializer = Serializers[model_name].new({
        :model_url_service => model_url_service
      })
      model_url = model_url_service.url_for_model(model, type: model_name)
      if !model_url
        current_export.logger.error "#{model_name}: #{model_url} could not be serialized"
        return false
      elsif archiver.seen?(model_name, model_url)
        current_export.logger.info "#{model_name}: #{model_url} already serialized"
        return false
      else
        current_export.logger.info "#{model_name}: #{model_url} serialized to json"
        archiver.write(model_name: model_name, data: serializer.serialize(model))
        archiver.seen(model_name, model_url)
        return true
      end
    end
  end
end
