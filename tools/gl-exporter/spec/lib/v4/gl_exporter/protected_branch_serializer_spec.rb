require 'spec_helper'

describe GlExporter::ProtectedBranchSerializer, :v4 do
  let(:protected_branch) do
    VCR.use_cassette("v4/gitlab-branch") do
      Gitlab.branch(1169162, "master")
    end
  end

  let(:project) do
    VCR.use_cassette("v4/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:group) do
    VCR.use_cassette("v4/gitlab-group") do
      Gitlab.group("hackmouse")
    end
  end

  describe "#serialize" do
    let(:protected_branch_serializer) { described_class.new }
    subject { protected_branch_serializer.serialize(protected_branch) }

    before(:each) do
      protected_branch["repository"] = project
      protected_branch["creator"] = group
    end

    it "returns a serialized protected branch" do
      expected = {
          type:                                     "protected_branch",
          name:                                     "master",
          url:                                      "https://gitlab.com/Mouse-Hack/hugo-pages/protected_branches/master",
          creator_url:                              "https://gitlab.com/groups/hackmouse",
          repository_url:                           "https://gitlab.com/Mouse-Hack/hugo-pages",
          admin_enforced:                           true,
          block_deletions_enforcement_level:        2,
          block_force_pushes_enforcement_level:     2,
          dismiss_stale_reviews_on_push:            false,
          pull_request_reviews_enforcement_level:   "off",
          require_code_owner_review:                false,
          required_status_checks_enforcement_level: "off",
          strict_required_status_checks_policy:     false,
          authorized_actors_only:                   false,
          authorized_user_urls:                     [],
          authorized_team_urls:                     [],
          dismissal_restricted_user_urls:           [],
          dismissal_restricted_team_urls:           [],
          required_status_checks:                   []
        }

      expected.each do |key, value|
        expect(subject[key]).to eq(value)
      end
    end
  end
end
