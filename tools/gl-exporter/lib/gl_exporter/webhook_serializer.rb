class GlExporter

  # Serializes Webhooks from GitLab's Webhooks
  #
  # #### Model Example:
  #
  # ```
  # {"id"=>50703,
  #  "url"=>"http://requestb.in/1izuozf1",
  #  "created_at"=>"2016-07-07T20:36:26.639Z",
  #  "project_id"=>1169162,
  #  "push_events"=>true,
  #  "issues_events"=>false,
  #  "merge_requests_events"=>false,
  #  "tag_push_events"=>true,
  #  "note_events"=>true,
  #  "build_events"=>false,
  #  "enable_ssl_verification"=>true}
  # ```
  class WebhookSerializer < BaseSerializer

    EVENT_MAPPINGS = {
      "push_events" => "push",
      "issues_events" => "issue",
      "merge_requests_events" => "pull_request",
      "tag_push_events" => "release",
      "note_events" => ["issue_comment", "pull_request_review_comment"],
      "build_events" => "status",
    }

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :payload_url => url,
        :content_type => "json",
        :event_types => events,
        :enable_ssl_verification => verify_ssl?,
        :active => true
      }
    end

    private

    def url
      gl_model["url"]
    end

    def events
      EVENT_MAPPINGS.select { |k,v| gl_model[k] }.flat_map { |k,v| v }
    end

    def verify_ssl?
      gl_model["enable_ssl_verification"]
    end
  end
end
