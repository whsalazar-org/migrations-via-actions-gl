module ApiVersionHelpers
  BASE_URL = "https://gitlab.com/api".freeze

  def api_v3!
    Gitlab.api_endpoint = api_url("v3")
  end

  def api_v4!
    Gitlab.api_endpoint = api_url("v4")
  end

  private

  def api_url(path)
    File.join(BASE_URL, path)
  end
end
