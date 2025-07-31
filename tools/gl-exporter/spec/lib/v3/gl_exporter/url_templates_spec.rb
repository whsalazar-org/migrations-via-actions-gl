require "spec_helper"

describe GlExporter::UrlTemplates, :v3 do
  let(:templates) { described_class.new.templates }

  it "extracts user info" do
    params = extract("http://gitlab.com/u/hubot", "user")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "segments" => ["u"],
        "user" => "hubot",
      }
    )
  end

  it "extracts user info with alternate path" do
    params = extract("http://gitlab.com/hubot", "user")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "segments" => nil,
        "user" => "hubot",
      }
    )
  end

  it "extracts group info" do
    params = extract("http://gitlab.com/groups/github", "organization")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "organization" => "github",
      }
    )
  end

  it "extracts team info" do
    params = extract("http://gitlab.com/groups/github/teams/ruby-developers", "team")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "team" => "ruby-developers",
      }
    )
  end

  it "extracts project info" do
    params = extract("http://gitlab.com/github/gl-exporter", "repository")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
      }
    )
  end

  it "extracts milestone info" do
    params = extract("http://gitlab.com/github/gl-exporter/milestones/123", "milestone")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "milestone" => "123",
      }
    )
  end

  it "extracts issue info" do
    params = extract("http://gitlab.com/github/gl-exporter/issues/123", "issue")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "issue" => "123",
      }
    )
  end

  it "extracts merge request info" do
    params = extract("http://gitlab.com/github/gl-exporter/merge_requests/123", "pull_request")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "pull_request" => "123",
      }
    )
  end

  it "extracts merge request diff note info" do
    params = extract("http://gitlab.com/github/gl-exporter/merge_requests/123/diffs#note_456", "pull_request_review_comment")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "pull_request" => "123",
        "pull_request_review_comment" => "456",
      }
    )
  end

  it "extracts commit comment info" do
    params = extract("http://gitlab.com/github/gl-exporter/commit/eb2fc5e139efde5a747c54530df8ef59c3f5b026#note_456", "commit_comment")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "commit" => "eb2fc5e139efde5a747c54530df8ef59c3f5b026",
        "commit_comment" => "456",
      }
    )
  end

  it "extracts issue note info" do
    params = extract("http://gitlab.com/github/gl-exporter/issues/123#note_456", "issue_comment", "issue")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "number" => "123",
        "issue_comment" => "456",
      }
    )
  end

  it "extracts merge request note info" do
    params = extract("http://gitlab.com/github/gl-exporter/merge_requests/123#note_456", "issue_comment", "pull_request")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "number" => "123",
        "issue_comment" => "456",
      }
    )
  end

  it "extracts tag info" do
    params = extract("http://gitlab.com/github/gl-exporter/tags/v1.2", "release")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "release" => "v1.2",
      }
    )
  end

  it "extracts label info" do
    params = extract("http://gitlab.com/github/gl-exporter/labels#/bug", "label")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "gitlab.com",
        "owner" => "github",
        "repository" => "gl-exporter",
        "label" => "bug",
      }
    )
  end

  it "can handle a specified port number" do
    params = extract("http://example.com:123/u/hubot", "user")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "example.com:123",
        "segments" => ["u"],
        "user" => "hubot",
      }
    )
  end

  it "can handle subdomains" do
    params = extract("http://this.has.manysubdomains.com/u/hubot", "user")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "this.has.manysubdomains.com",
        "segments" => ["u"],
        "user" => "hubot",
      }
    )
  end

  it "can handle localhost" do
    params = extract("http://localhost/u/hubot", "user")
    expect(params).to eq(
      {
        "scheme" => "http",
        "host" => "localhost",
        "segments" => ["u"],
        "user" => "hubot",
      }
    )
  end

  def extract(uri, *template_name)
    uri = Addressable::URI.parse(uri)
    template = Addressable::Template.new(template_name.inject(templates, :[]))
    template.extract(uri)
  end
end
