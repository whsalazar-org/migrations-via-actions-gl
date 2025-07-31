class GlExporter
  module Attachable
    ATTACHMENT_REGEX= /\[(?<link_text>.*?)\]\((?<attach_path>\/uploads\/.+?)\)/

    def model_url_service
      @model_url_service ||= ModelUrlService.new
    end

    # Scan user content for inline attachments, serialize those attachments, and
    # update the user content to reflect the new URL.
    #
    # @param [String] type the model type we are extracting attachments from
    # @param [Hash] model the model we are extracting attachments from
    def extract_attachments(type, model)
      body_key = ["body", "note", "description"].detect { |x| model[x] }
      model[body_key] = model[body_key].to_s.gsub(ATTACHMENT_REGEX) do
        match = $~
        attach_path = match[:attach_path]
        tmp_model = {
          "type"        => type,
          "model"       => model,
          "repository"  => project,
          "attach_path" => attach_path.to_s.gsub("\\", ""),
        }
        attach_url = model_url_service.url_for_model(tmp_model, type: "attachment")
        parent_url = model_url_service.url_for_model(model, type: type)
        next unless archiver.save_attachment(attach_path, attach_url, parent_url)
        serialize("attachment", tmp_model)

        "[#{match[:link_text]}](#{attach_url})"
      end
    end
  end
end
