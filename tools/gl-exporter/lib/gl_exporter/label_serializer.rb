class GlExporter

  # Serializes Labels from GitLab's Labels
  #
  # #### Model Example:
  #
  # ```
  # {"name"=>"test-label",
  # "color"=>"#69d100"}
  # ```
  class LabelSerializer < BaseSerializer

    # @see GlExporter::BaseSerializer#to_gh_hash
    def to_gh_hash
      {
        :type => 'label',
        :url => url_for_model(gl_model, type: 'label'),
        :name => gl_model["name"],
        :color => color,
        :created_at => Time.now
      }
    end

    private

    def color
      gl_model["color"][/\w+/]
    end
  end
end
