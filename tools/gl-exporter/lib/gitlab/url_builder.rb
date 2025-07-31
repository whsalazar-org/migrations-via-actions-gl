class Gitlab
  class UrlBuilder
    attr_accessor :url, :opts

    def initialize(path="/", opts={})
      @url = File.join(Gitlab.api_endpoint, path)
      @opts = opts
    end

    # Returns the built URI as a string
    def to_s
      built_url.to_s
    end

    # Build the url with options and parameters
    def built_url
      URI.parse(url).tap do |uri|
        if opts[:params]
          combined_query = URI.decode_www_form(uri.query.to_s) + opts[:params].to_a
          uri.query = URI.encode_www_form(combined_query)
        end
      end
    end

  end
end
