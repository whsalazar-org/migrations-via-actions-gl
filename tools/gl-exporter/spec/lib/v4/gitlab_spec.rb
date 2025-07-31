require "spec_helper"

describe Gitlab, :v4 do
  describe "#get" do
    it "can traverse standard pagination to fetch all records" do
      issues = VCR.use_cassette("v4/gitlab-issues/Mouse-Hack/many-commits") do
        Gitlab.get("projects/1316735/issues", auto_paginate: :standard)
      end
      expect(issues.length).to eq(500)
    end

    it "can traverse standard pagination to fetch all branches" do
      branches = VCR.use_cassette("v4/gitlab-branches/Mouse-Hack/test-branch-protections") do
        Gitlab.branches("11923805")
      end
      expect(branches.length).to eq(23)
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

  describe "#user", :vcr do
    it "fetches a user by Integer ID" do
      # Passing an argument is deprecated
      expect(Gitlab).to receive(:warn)

      user = Gitlab.user(4676821)

      expect(user["username"]).to eq("78491623")
    end

    it "fetches a user by String ID" do
      # Passing an argument is deprecated
      expect(Gitlab).to receive(:warn)

      user = Gitlab.user("4676821")

      expect(user["username"]).to eq("78491623")
    end

    it "fetches a user by username" do
      # Passing an argument is deprecated
      expect(Gitlab).to receive(:warn)

      user = Gitlab.user("kylemacey")

      expect(user["username"]).to eq("kylemacey")
    end
  end

  describe "#user_by_id", :vcr do
    it "fetches a user by Integer ID" do
      user = Gitlab.user_by_id(4676821)

      expect(user["username"]).to eq("78491623")
    end

    it "fetches a user by String ID" do
      user = Gitlab.user_by_id("4676821")

      expect(user["username"]).to eq("78491623")
    end
  end

  describe "#user_by_username", :vcr do
    it "fetches a user by username" do
      user = Gitlab.user_by_username("78491623")

      expect(user["username"]).to eq("78491623")
    end

    it "returns a hash" do
      user = Gitlab.user_by_username("78491623")

      expect(user).to be_a(Hash)
    end

    context "for a user that doens't exist" do
      it "returns nil" do
        user = Gitlab.user_by_username("test-for-a-user-that-should-not-exist")

        expect(user).to be_nil
      end
    end
  end

  describe "#labels", :vcr do
    it "paginates through all results" do
      labels = Gitlab.labels(25693144)

      expect(labels.count).to eq(36)
    end
  end
end
