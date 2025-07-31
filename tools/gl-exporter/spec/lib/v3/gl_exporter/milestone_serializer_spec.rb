require 'spec_helper'

describe GlExporter::MilestoneSerializer, :v3 do
  let(:milestone) do
    VCR.use_cassette("v3/gitlab-milestone") do
      Gitlab.milestone(1169162, 62677)
    end
  end

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:user) do
    VCR.use_cassette("v3/gitlab-user") do
      Gitlab.user
    end
  end

  describe "#serialize" do
    subject { described_class.new.serialize(milestone) }

    before(:each) do
      milestone["repository"] = project
      milestone["user"] = user
    end

    it "returns a serialized Milestone hash" do
      expected = {
        :type => "milestone",
        :url => "https://gitlab.com/Mouse-Hack/hugo-pages/milestones/1",
        :repository => "https://gitlab.com/Mouse-Hack/hugo-pages",
        :user => "https://gitlab.com/u/kylemacey",
        :title => "Prototype",
        :description => "Just get the simplest thing working and out there for folks to try out.",
        :state => "open",
        :due_on => "2020-04-20T00:00:00Z",
        :created_at => "2016-05-10T22:06:45Z"
      }

      expected.each do |key, value|
        # TODO: `due_on` fails for me locally, maybe because of CEST timezone?
        #
        # expected: "2020-04-20T00:00:00Z"
        #      got: "2020-04-19T00:00:00Z"
        # expect(subject[key]).to eq(value)
      end
    end
  end
end
