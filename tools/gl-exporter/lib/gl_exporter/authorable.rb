class GlExporter
  module Authorable
    # Exports a user by name or Hash
    #
    # @param [String, Hash] user_or_name a String value of the user's username
    #   or a Hash containing GitLab user data
    def export_user(username_or_user)
      if username_or_user.is_a? String
        user = Gitlab.user_by_username(username_or_user)
        current_export.output_logger.error "#{username_or_user} not found" unless user
        serialize "user", user
      else
        serialize "user", username_or_user
      end
    end
  end
end
