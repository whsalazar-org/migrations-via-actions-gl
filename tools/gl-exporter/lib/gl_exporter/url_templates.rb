class GlExporter::UrlTemplates
  def templates
    {
      "user"                        => "{scheme}://{+host}{/segments*}/{user}",
      "organization"                => "{scheme}://{+host}/groups/{organization}",
      "team"                        => "{scheme}://{+host}/groups/{owner}/teams/{team}",
      "repository"                  => "{scheme}://{+host}/{owner}/{repository}",
      "protected_branch"            => "{scheme}://{+host}/{owner}/{repository}/protected_branches/{protected_branch}",
      "milestone"                   => "{scheme}://{+host}/{owner}/{repository}/milestones/{milestone}",
      "issue"                       => "{scheme}://{+host}/{owner}/{repository}/issues/{issue}",
      "pull_request"                => "{scheme}://{+host}/{owner}/{repository}/merge_requests/{pull_request}",
      "pull_request_review_comment" => "{scheme}://{+host}/{owner}/{repository}/merge_requests/{pull_request}/diffs#note_{pull_request_review_comment}",
      "commit_comment"              => "{scheme}://{+host}/{owner}/{repository}/commit/{commit}#note_{commit_comment}",
      "issue_comment"               => {
        "issue"        => "{scheme}://{+host}/{owner}/{repository}/issues/{number}#note_{issue_comment}",
        "pull_request" => "{scheme}://{+host}/{owner}/{repository}/merge_requests/{number}#note_{issue_comment}",
      },
      "release"                     => "{scheme}://{+host}/{owner}/{repository}/tags/{release}",
      "label"                       => "{scheme}://{+host}/{owner}/{repository}/labels#/{label}",
    }
  end
end
