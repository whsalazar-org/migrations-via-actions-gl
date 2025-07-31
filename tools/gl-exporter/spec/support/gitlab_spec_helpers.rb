module GitlabSpecHelpers
  def with_ssl_verify(value, &block)
    old_ssl_verify = Gitlab.ssl_verify
    Gitlab.ssl_verify = value
    block.call
    Gitlab.ssl_verify = old_ssl_verify
  end
end
