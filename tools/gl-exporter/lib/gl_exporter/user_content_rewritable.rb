class GlExporter
  module UserContentRewritable
    ISSUE_MR_REGEX = /([^\w])([#|!])(\d+)/

    # Detects the hash key for `model`'s content body and rewrites that content
    def rewrite_user_content!
      body_key = ["body", "note", "description"].detect { |x| model[x] }
      rewrite_numeric_mentions(body_key)
    end

    # Rewrites mentions in content bodies to Issues and Pull Requests that use
    # `#n` or `!n`
    #
    # @param [String] body_key since content bodies have various attribute names,
    #   pass in the name for that attribute
    def rewrite_numeric_mentions(body_key)
      model[body_key] = model[body_key].to_s.gsub(ISSUE_MR_REGEX) do |match|
        "#{$1}##{translate_id($2, $3)}"
      end
    end

    # For a given issue or merge_request id, return the new rewritten id
    #
    # @param [String] indicator `!` or `#` to determine if we are getting the id
    #   for a merge request or issue
    # @param [Integer,String] old_id the id before it was rewritten
    # @return [Integer] the rewritten id
    def translate_id(indicator, old_id)
      model_name = (indicator == "!") ? :merge_requests : :issues
      new_id = project_exporter.rewritten_ids[model_name][old_id.to_i]
      (new_id || old_id).to_s
    end
  end
end
