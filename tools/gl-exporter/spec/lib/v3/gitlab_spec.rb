require "spec_helper"

describe Gitlab, :v3 do
  describe "#get" do
    it "can traverse legacy pagination to fetch all records" do
      commits = VCR.use_cassette("v3/gitlab-commits/Mouse-Hack/many-commits") do
        Gitlab.get("projects/1316735/repository/commits", auto_paginate: :legacy)
      end
      expect(commits.length).to eq(500)
    end

    it "can traverse standard pagination to fetch all records" do
      issues = VCR.use_cassette("v3/gitlab-issues/Mouse-Hack/many-commits") do
        Gitlab.get("projects/1316735/issues", auto_paginate: :standard)
      end
      expect(issues.length).to eq(500)
    end
  end

  describe "#connection" do
    before(:each) do
      # Reset memoized @connection var for tests
      Gitlab.instance_variable_set(:@connection, nil)
    end

    it "enforces SSL verification" do
      with_ssl_verify(true) do
        expect(Gitlab.connection.ssl.verify?).to be(true)
      end
    end

    it "disables SSL verification" do
      with_ssl_verify(false) do
        expect(Gitlab.connection.ssl.verify?).to be(false)
      end
    end
  end

  describe "#ssl_verify" do
    it "can be set false by an environment variable" do
      Gitlab.ssl_verify = nil
      ClimateControl.modify GITLAB_SSL_VERIFY: "false" do
        expect(Gitlab.ssl_verify).to eq(false)
      end
    end

    it "can be set true by an environment variable" do
      Gitlab.ssl_verify = nil
      ClimateControl.modify GITLAB_SSL_VERIFY: "true" do
        expect(Gitlab.ssl_verify).to eq(true)
      end
    end
  end
end
