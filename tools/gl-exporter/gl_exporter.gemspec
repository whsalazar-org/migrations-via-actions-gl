lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gl_exporter/version'

Gem::Specification.new do |spec|
  spec.name          = 'gl_exporter'
  spec.version       = GlExporter::VERSION
  spec.authors       = ['GitHub', 'Kyle Macey']
  spec.email         = ['opensource+gl-exporter@github.com', 'services@github.com']

  spec.summary       = 'A ruby utility for exporting GitLab repositories to be imported by ghe-migrator'
  spec.description   = 'A ruby utility for exporting GitLab repositories to be imported by ghe-migrator'
  spec.homepage      = 'https://github.com/github/gl-exporter'

  spec.files         = %w[CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE README.md Rakefile gl_exporter.gemspec]
  spec.files += Dir.glob('{bin,exe,lib,script}/**/*')
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '~> 3.2.1'

  spec.add_dependency 'activesupport', '~> 7.0.8'
  spec.add_dependency 'dotenv', '~> 2.8.1'
  spec.add_dependency 'faraday', '~> 1.10.3'
  spec.add_dependency 'faraday-http-cache', '~> 2.4.1'
  spec.add_dependency 'faraday_middleware', '~> 1.2.0'
  spec.add_dependency 'posix-spawn', '~> 0.3.15'
  spec.add_dependency 'rugged', '~> 1.7.2'
  spec.add_development_dependency 'addressable', '~> 2.8.1'
  spec.add_development_dependency 'bundler', '>=2.4.1'
  spec.add_development_dependency 'climate_control', '~> 1.2.0'
  spec.add_development_dependency 'github-markup', '~> 4.0.1'
  spec.add_development_dependency 'rake', '~> 13.0.6'
  spec.add_development_dependency 'redcarpet', '~> 3.6.0'
  spec.add_development_dependency 'yard', '~> 0.9.28'
end
