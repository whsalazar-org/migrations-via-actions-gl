require "dotenv"
Dotenv.load('.env.test')

require "fileutils"
require "gl_exporter"
require "rspec"
require "vcr"
require "webmock/rspec"
require "addressable"
require "climate_control"
require "pry"

# Require support files

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

include ApiVersionHelpers
include GitlabSpecHelpers

VCR.configure do |config|
  config.configure_rspec_metadata!
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<API_TOKEN>') { Gitlab.token }
end

RSpec.configure do |config|
  config.before(:each) do
    allow_any_instance_of(GlExporter::Logging).to receive(:logger).and_return(NullLogger.new)
    allow_any_instance_of(GlExporter::Logging).to receive(:output_logger).and_return(NullLogger.new)
  end

  config.before(:each, :v3) { skip "API V3 is no longer supported." }
  config.before(:each, :v4) { api_v4! }

  config.after(:each) do
    if File.exist?(Gitlab.http_cache_path)
      FileUtils.remove_entry_secure(Gitlab.http_cache_path)
    end

    GlExporter::Storage.drop!
  end
end
