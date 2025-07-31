require "spec_helper"

describe GlExporter::ProjectExporter, :v3 do
  let(:project_exporter) { described_class.new(project, current_export: gl_exporter) }

  let(:gl_exporter) { GlExporter.new(models: GlExporter::OPTIONAL_MODELS) }

  let(:project) do
    VCR.use_cassette("v3/gitlab-projects/Mouse-Hack/hugo-pages") do
      Gitlab.project("Mouse-Hack", "hugo-pages")
    end
  end

  let(:project_owner) do
    VCR.use_cassette("v3/gitlab-export-owner/Mouse-Hack/hugo-pages") do
      Gitlab.group("Mouse-Hack")
    end
  end

  before(:each) do
    allow(gl_exporter.archiver).to receive(:write)
    allow(gl_exporter.archiver).to receive(:clone_repo)
    allow(gl_exporter.archiver).to receive(:clone_wiki)
  end

  describe "#serialize" do
    let(:user) do
      VCR.use_cassette("v3/gitlab-user") do
        Gitlab.user
      end
    end

    it "doesn't serialize the same model twice" do
      expect(project_exporter.serialize("user", user)).to eq(true)
      expect(project_exporter.serialize("user", user)).to eq(false)
    end
  end

  describe "#export" do
    subject do
      VCR.use_cassette("v3/gl_exporter/project_exporter/export/#{project["path_with_namespace"]}") do
        project_exporter.export
      end
    end

    before do
      allow(project_exporter).to receive(:export_issues)
      allow(project_exporter).to receive(:export_merge_requests)
      allow(project_exporter).to receive(:export_tags)
      allow(project_exporter).to receive(:export_commit_comments)
      allow(project_exporter).to receive(:export_authenticated_user)
      allow(project_exporter).to receive(:export_milestones)
      allow(project_exporter).to receive(:export_wiki)
      allow(project_exporter).to receive(:export_collaborators).and_return([])
      allow(project_exporter).to receive(:export_protected_branches)
      allow(project_exporter).to receive(:export_hooks)
      allow(project_exporter).to receive(:export_wiki)
    end

    it "exports other models" do
      expect(project_exporter).to receive(:export_issues)
      expect(project_exporter).to receive(:export_merge_requests)
      expect(project_exporter).to receive(:export_tags)
      expect(project_exporter).to receive(:export_commit_comments)
      expect(project_exporter).to receive(:export_authenticated_user)
      expect(project_exporter).to receive(:export_milestones)
      expect(project_exporter).to receive(:export_wiki)
      expect(project_exporter).to receive(:export_collaborators).and_return([])
      expect(project_exporter).to receive(:export_protected_branches)
      expect(project_exporter).to receive(:export_hooks)
      subject
    end

    context "with selective export excluding commit comments" do
      let(:gl_exporter) { GlExporter.new(models: %w(issues merge_requests hooks wiki)) }

      it "exports only the provided models" do
        expect(project_exporter).to receive(:export_issues)
        expect(project_exporter).to receive(:export_merge_requests)
        expect(project_exporter).to receive(:export_tags)
        expect(project_exporter).to_not receive(:export_commit_comments)
        expect(project_exporter).to receive(:export_protected_branches)
        expect(project_exporter).to receive(:export_hooks)
        expect(project_exporter).to receive(:export_wiki)
        subject
      end
    end

    context "with selective export excluding issues" do
      let(:gl_exporter) { GlExporter.new(models: %w(merge_requests commit_comments hooks wiki)) }

      it "exports only the provided models" do
        expect(project_exporter).to_not receive(:export_issues)
        expect(project_exporter).to receive(:export_merge_requests)
        expect(project_exporter).to receive(:export_tags)
        expect(project_exporter).to receive(:export_commit_comments)
        expect(project_exporter).to receive(:export_protected_branches)
        expect(project_exporter).to receive(:export_hooks)
        expect(project_exporter).to receive(:export_wiki)
        subject
      end
    end

    context "with selective export excluding merge requests" do
      let(:gl_exporter) { GlExporter.new(models: %w(issues commit_comments hooks wiki)) }

      it "exports only the provided models" do
        expect(project_exporter).to receive(:export_issues)
        expect(project_exporter).to_not receive(:export_merge_requests)
        expect(project_exporter).to receive(:export_tags)
        expect(project_exporter).to receive(:export_commit_comments)
        expect(project_exporter).to receive(:export_protected_branches)
        expect(project_exporter).to receive(:export_hooks)
        expect(project_exporter).to receive(:export_wiki)
        subject
      end
    end

    context "with selective export excluding hooks" do
      let(:gl_exporter) { GlExporter.new(models: %w(issues commit_comments merge_requests wiki)) }

      it "exports only the provided models" do
        expect(project_exporter).to receive(:export_issues)
        expect(project_exporter).to receive(:export_merge_requests)
        expect(project_exporter).to receive(:export_tags)
        expect(project_exporter).to receive(:export_commit_comments)
        expect(project_exporter).to receive(:export_protected_branches)
        expect(project_exporter).to_not receive(:export_hooks)
        expect(project_exporter).to receive(:export_wiki)
        subject
      end
    end

    context "with selective export excluding wiki" do
      let(:gl_exporter) { GlExporter.new(models: %w(issues commit_comments merge_requests hooks)) }

      it "exports only the provided models" do
        expect(project_exporter).to receive(:export_issues)
        expect(project_exporter).to receive(:export_merge_requests)
        expect(project_exporter).to receive(:export_tags)
        expect(project_exporter).to receive(:export_commit_comments)
        expect(project_exporter).to receive(:export_protected_branches)
        expect(project_exporter).to_not receive(:export_wiki)
        subject
      end
    end

    context "with merge requests disabled" do
      before do
        project["merge_requests_enabled"] = false
      end

      it "does not export merge requests" do
        expect(Gitlab).to_not receive(:merge_requests)
        subject
      end
    end

    context "with issues disabled" do
      before do
        project["issues_enabled"] = false
      end

      it "does not export issues" do
        expect(Gitlab).to_not receive(:issues)
        subject
      end
    end

    context "with wikis disabled" do
      before do
        project["wiki_enabled"] = false
      end

      it "does not export the wiki" do
        expect(gl_exporter.archiver).to_not receive(:clone_wiki)
        subject
      end
    end

    it "renumbers both issues and merge requests by default" do
      expect(project_exporter).to receive(:renumber_issues_and_merge_requests)
        .with(skip: nil)
      subject
    end

    context "without renumbering issues" do
      let(:gl_exporter) { GlExporter.new(without_renumbering: :issues) }

      it "does not renumber issues" do
        expect(project_exporter).to receive(:renumber_issues_and_merge_requests)
          .with(skip: :issues)
        subject
      end
    end

    context "without renumbering merge requests" do
      let(:gl_exporter) { GlExporter.new(without_renumbering: :merge_requests) }

      it "does not renumber merge requests" do
        expect(project_exporter).to receive(:renumber_issues_and_merge_requests)
          .with(skip: :merge_requests)
        subject
      end
    end
  end

  describe "#export_authenticated_user" do
    let(:user) do
      VCR.use_cassette("v3/gitlab-user") do
        Gitlab.user
      end
    end

    it "exports the users performing the export" do
      expect(Gitlab).to receive(:user).and_return(user)
      expect(project_exporter).to receive(:export_user).with(user)
      project_exporter.export_authenticated_user
    end
  end

  describe "#export_user" do
    let(:user) do
      VCR.use_cassette("v3/gitlab-user") do
        Gitlab.user
      end
    end

    context "when provided a username" do
      subject { project_exporter.export_user(user["username"]) }

      it "Fetches the user then serializes it" do
        expect(Gitlab).to receive(:user_by_username).and_return(user)
        expect(project_exporter).to receive(:serialize).with("user", user)
        subject
      end
    end

    context "when provided a user hash" do
      subject { project_exporter.export_user(user) }

      it "serializes that hash" do
        expect(project_exporter).to receive(:serialize).with("user", user)
        subject
      end
    end
  end

  describe "#export_collaborators" do
    subject do
      VCR.use_cassette("v3/gl_exporter/project_exporter/export_collaborators") do
        project_exporter.export_collaborators
      end
    end

    before(:each) do
      allow(project_exporter).to receive(:export_user)
    end

    it "returns an array of collaborators" do
      expect(subject).to all be_a(Hash)
        .and have_key("username")
    end

    it "exports each collaborator as a user" do
      # The VCR cassette has this project with 1 collaborator
      expect(project_exporter).to receive(:export_user)
        .exactly(1).times
      subject
    end
  end

  describe "#export_owner_of_project" do
    subject do
      VCR.use_cassette("v3/gitlab-export-owner/#{project["path_with_namespace"]}") do
        project_exporter.export_owner_of_project
      end
    end

    context "when project is owned by a user" do
      let(:project) do
        VCR.use_cassette("v3/gitlab-projects/kylemacey/Spoon-Knife") do
          Gitlab.project('kylemacey', 'Spoon-Knife')
        end
      end

      it "fetches a user from Gitlab" do
        allow(project_exporter).to receive(:export_user)
        subject
      end

      it "attempts to export a user" do
        expect(project_exporter).to receive(:export_user)
        subject
      end
    end

    context "when project is owned by a group" do
      it "fetches a group from Gitlab" do
        allow(project_exporter).to receive(:export_group)
        subject
      end

      it "attempts to export a group" do
        expect(project_exporter).to receive(:export_group)
        subject
      end
    end
  end

  describe "#export_milestones" do
    subject { project_exporter.export_milestones }
    let(:milestones) do
      [
        {
          "id"          => 1,
          "title"       => "Prototype",
        },
        {
          "id"          => 2,
          "title"       => "Prototype",
        },
        {
          "id"          => 3,
          "title"       => "Prototype",
        },
        {
          "id"          => 4,
          "title"       => "Something else",
        }
      ]
    end

    before { allow(Gitlab).to receive(:milestones).and_return(milestones) }

    it "fixes duplicate milestone titles" do
      expect(project_exporter).to receive(:export_milestone)
        .with(include("title" => "Prototype")).exactly(1).times
      expect(project_exporter).to receive(:export_milestone)
        .with(include("title" => "Prototype (1)")).exactly(1).times
      expect(project_exporter).to receive(:export_milestone)
        .with(include("title" => "Prototype (2)")).exactly(1).times
      expect(project_exporter).to receive(:export_milestone)
        .with(include("title" => "Something else")).exactly(1).times
      subject
    end

    it "does not export milestones if neither issues or merge requests are enabled" do
      project["issues_enabled"] = false
      project["merge_requests_enabled"] = false
      expect(project_exporter).to_not receive(:export_milestone)
      subject
    end

    it "exports milestones if merge requests are enabled" do
      project["issues_enabled"] = false
      project["merge_requests_enabled"] = true
      expect(project_exporter).to receive(:export_milestone).at_least(1).times
      subject
    end

    it "exports milestones if issues are enabled" do
      project["issues_enabled"] = true
      project["merge_requests_enabled"] = false
      expect(project_exporter).to receive(:export_milestone).at_least(1).times
      subject
    end
  end

  describe "#export_protected_branches" do
    subject do
      VCR.use_cassette("v3/gitlab-export-protected-branches/#{project["path_with_namespace"]}") do
        project_exporter.export_protected_branches
      end
    end

    it "fetches protected_branches from gitlab" do
      allow(project_exporter).to receive(:export_protected_branch)
      expect(Gitlab).to receive(:branches).with(project["id"]).and_call_original
      subject
    end

    it "exports all of the protected_branches" do
      expect(project_exporter).to receive(:export_protected_branch).exactly(2).times
      subject
    end
  end

  describe "#export_issues" do
    subject do
      VCR.use_cassette("v3/gitlab-export-issues/#{project["path_with_namespace"]}") do
        project_exporter.export_issues
      end
    end

    it "fetches issues from gitlab" do
      allow(project_exporter).to receive(:prepare_issue_for_export)
      expect(Gitlab).to receive(:issues).with(project["id"]).and_call_original
      subject
    end

    it "exports all of the issues" do
      expect(project_exporter).to receive(:prepare_issue_for_export).exactly(5).times
      subject
    end
  end

  describe "#prepare_issue_for_export" do
    subject do
      project_exporter.prepare_issue_for_export(issue)
    end

    let(:issue) do
      VCR.use_cassette("v3/gitlab-closed-issue") do
        Gitlab.issue(1169162, 2191619)
      end
    end

    it "intializes an export object and adds it to `@issues`" do
      expect(GlExporter::IssueExporter).to receive(:new).with(
        issue,
        project_exporter: project_exporter,
      )
      expect{subject}.to change{project_exporter.issues.length}.by(1)
    end
  end

  describe "#prepare_merge_requests_for_export" do
    subject do
      VCR.use_cassette("v3/gitlab-export-merge_requests/#{project["path_with_namespace"]}") do
        project_exporter.prepare_merge_requests_for_export
      end
    end

    before(:each) do
      allow(project_exporter).to receive(:project_owner).and_return(project_owner)
    end

    it "fetches merge_requests from gitlab" do
      allow(project_exporter).to receive(:prepare_merge_request_for_export)
      expect(Gitlab).to receive(:merge_requests).with(project["id"]).and_call_original
      subject
    end

    it "exports all of the merge_requests" do
      expect(project_exporter).to receive(:prepare_merge_request_for_export).exactly(3).times
      subject
    end
  end

  describe "#prepare_merge_request_for_export" do
    subject do
      VCR.use_cassette("v3/gitlab-merge-request-commits") do
        project_exporter.prepare_merge_request_for_export(merge_request)
      end
    end

    let(:merge_request) do
      VCR.use_cassette("v3/gitlab-merge-request") do
        Gitlab.merge_request(1169162, 476834)
      end
    end

    before(:each) do
      allow(project_exporter).to receive(:project_owner).and_return(project_owner)
    end

    it "intializes an export object and adds it to `@merge_requests`" do
      expect(GlExporter::MergeRequestExporter).to receive(:new).with(
        merge_request,
        project_exporter: project_exporter,
        project_owner: project_owner,
      )
      expect{subject}.to change{project_exporter.merge_requests.length}.by(1)
    end
  end

  describe "#export_hooks" do
    subject do
      VCR.use_cassette("v3/gitlab-export-hooks/#{project["path_with_namespace"]}") do
        project_exporter.export_hooks
      end
    end

    it "fetches tags from gitlab" do
      expect(Gitlab).to receive(:webhooks).with(1169162).and_call_original
      subject
    end

    it "sets the webhooks for the project" do
      subject
      expect(project_exporter.project["webhooks"]).to_not be_empty
    end
  end

  describe "#export_tags" do
    subject do
      VCR.use_cassette("v3/gitlab-export-tags/#{project["path_with_namespace"]}") do
        project_exporter.export_tags
      end
    end

    it "fetches tags from gitlab" do
      allow(project_exporter).to receive(:export_tag)
      expect(Gitlab).to receive(:tags).with(1169162).and_call_original
      subject
    end

    it "exports only release tags" do
      expect(project_exporter).to receive(:export_tag).exactly(1).times
      subject
    end
  end

  describe "#export_tag" do
    subject do
      project_exporter.export_tag(tag)
    end

    let(:tag) do
      VCR.use_cassette("v3/gitlab-tag") do
        Gitlab.tag(1169162, "end-of-sinatra")
      end
    end

    let(:user) do
      VCR.use_cassette("v3/gitlab-user") do
        Gitlab.user
      end
    end

    before(:each) do
      tag["repository"] = project
      tag["user"] = user
    end

    it "serializes the tag" do
      expect(Gitlab).to receive(:user)
      expect(project_exporter).to receive(:serialize).with("release", tag)
      subject
    end
  end

  describe "#prepare_commit_comments_for_export" do
    subject do
      VCR.use_cassette("v3/gitlab-export-commit-comments/#{project["path_with_namespace"]}") do
        project_exporter.prepare_commit_comments_for_export
      end
    end

    before(:each) do
      allow(gl_exporter.archiver).to receive(:save_attachment)
      allow(project_exporter).to receive(:export_user)
    end

    it "fetches commits from gitlab" do
      expect(Gitlab).to receive(:commits).with(1169162).and_call_original
      subject
    end

    it "gets comments for each commit" do
      expect(Gitlab).to receive(:commit_comments).at_least(1).times.and_call_original
      subject
    end

    it "exports each commit comment" do
      expect(project_exporter).to receive(:prepare_commit_comment_for_export).at_least(1).times.and_call_original
      subject
    end
  end

  describe "#prepare_commit_comment_for_export" do
    subject do
      VCR.use_cassette("v3/gitlab-export-commit-comments") do
        project_exporter.prepare_commit_comment_for_export(commit, commit_comment)
      end
    end

    let(:commit) do
      VCR.use_cassette("v3/gitlab-commit") do
        Gitlab.commit(1169162, "220d5dc2582a49d694c503abdb8cf25bcdd81dce")
      end
    end

    let(:commit_comment) do
      VCR.use_cassette("v3/gitlab-commit_comment") do
        Gitlab.commit_comments(1169162, "220d5dc2582a49d694c503abdb8cf25bcdd81dce").first
      end
    end

    before(:each) do
      allow(gl_exporter.archiver).to receive(:save_attachment)
      allow(project_exporter).to receive(:export_user)
    end

    it "intializes an export object and adds it to `@commit_comments`" do
      expect(GlExporter::CommitCommentExporter).to receive(:new).with(
        commit,
        commit_comment,
        project_exporter: project_exporter,
      )
      expect{subject}.to change{project_exporter.commit_comments.length}.by(1)
    end
  end

  describe "#export_wiki" do
    subject do
      VCR.use_cassette("v3/gitlab-wiki/#{project["path_with_namespace"]}") do
        project_exporter.export_wiki
      end
    end

    it "exports the project wiki" do
      expect(gl_exporter.archiver).to receive(:clone_wiki).with(hash_including "path_with_namespace" => project["path_with_namespace"])
      subject
    end
  end

  describe "#renumber_issues_and_merge_requests" do
    let(:issues) do
      [
        {
          "created_at" => DateTime.current - 5,
          "iid"       => 1
        },
        {
          "created_at" => DateTime.current - 3,
          "iid"        => 2
        },
        {
          "created_at" => DateTime.current - 1,
          "iid"        => 3
        },
      ]
    end

    let(:merge_requests) do
      [
        {
          "created_at" => DateTime.current - 4,
          "iid"        => 1
        },
        {
          "created_at" => DateTime.current - 2,
          "iid"        => 2
        },
      ]
    end

    before do
      project_exporter.issues = issues.map do |issue|
        PseudoExporter.new(PseudoModel[issue])
      end
      project_exporter.merge_requests = merge_requests.map do |merge_request|
        PseudoExporter.new(PseudoModel[merge_request])
      end
      allow_any_instance_of(PseudoExporter).to receive(:rewrite!)
    end

    it "renumbers issues and merge requests chronologically" do
      project_exporter.renumber_issues_and_merge_requests
      expect(project_exporter.issues.map(&:iid)).to eq([1, 3, 5])
      expect(project_exporter.merge_requests.map(&:iid)).to eq([2, 4])
    end

    context "when skipping issues" do
      it "does not renumber issues" do
        project_exporter.renumber_issues_and_merge_requests(skip: :issues)
        expect(project_exporter.issues.map(&:iid)).to eq([1, 2, 3])
        expect(project_exporter.merge_requests.map(&:iid)).to eq([4, 5])
      end

      it "renumbers merge requests when there are no issues" do
        project_exporter.issues = []
        project_exporter.renumber_issues_and_merge_requests(skip: :issues)
        expect(project_exporter.merge_requests.map(&:iid)).to eq([1, 2])
      end
    end

    context "when skipping merge requests" do
      it "does not renumber merge requests" do
        project_exporter.renumber_issues_and_merge_requests(skip: :merge_requests)
        expect(project_exporter.issues.map(&:iid)).to eq([3, 4, 5])
        expect(project_exporter.merge_requests.map(&:iid)).to eq([1, 2])
      end

      it "renumbers issues when there are no merge requests" do
        project_exporter.merge_requests = []
        project_exporter.renumber_issues_and_merge_requests(skip: :merge_requests)
        expect(project_exporter.issues.map(&:iid)).to eq([1, 2, 3])
      end
    end
  end
end
