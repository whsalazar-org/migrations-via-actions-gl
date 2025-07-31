# @title GitLab Exporter Features

# GitLab Exporter Features and Limitations

GitLab Exporter was designed to export project information and meta data from instances of GitLab in such a format that can be imported by GitHub Enterprise's `ghe-migrator`. While a majority of models and data can be successfully migrated, it does have some limitations, due to a lack of information provided by GitLab's API.

| Model | Can Export? | Notes |
| :---  | :---------: | :---  |
| Users | **Y** | Some attributes, such as email(s), are only available with administrator personal access tokens. See https://docs.gitlab.com/ee/api/users.html for details. |
| Groups | **Y** | Imported as "Organizations" |
| Group Members | **Y** | Imported as "Teams" |
| Subgroups & Subgroup Projects | **Y** | Each group and subgroup is exported as an organization which is then mapped to a single target organization on import. |
| Projects | **Y** | Imported as "Repositories" |
| Fork Relationships | **N** | Migrating fork relationships is not supported by `ghe-migrator` and is not currently on the roadmap for GitLab Exporter. **NOTE:** Fork repos can be migrated but all fork relationships will not carry over. See limitations section below. |
| Protected branches | **Y** | Protected branch settings and associated data are migrated with teams creation. See limitations section below. |
| Project Team Members | **Y** | Imported as "Repository Collaborators"; Requires GitHub Enterprise 2.7 |
| Merge Requests | **Y** | Imported as "Pull Requests"; renumbered sequentially along with Issues |
| Merge Request Notes | **Y** | Imported as "Issue Comments"; GitLab does not provide enough data to determine diff notes, so all are imported inline. See limitations section below. |
| Issues | **Y** | |
| Issue Notes | **Y** | Imported as "Issue Comments" |
| Events | **Y** | Events are imported as Issue Comments, since GitLab's API does not provide enough information to build robust Events in GitHub |
| Webhooks | **Y** | Requires GitHub Enterprise 2.7 |
| Attachments | **Y** | GitLab announced changes to their API that now enforce personal access tokens to work only with API, RSS, and registry resources. This change has broken how we download non-image attachments as we can no longer retrieve them via personal access token. This affects all GitLab versions from `11.5.1`, `11.4.8`, and `11.3.11` and onward, including GitLab.com. `gl-exporter` will skip exporting any unreachable non-image attachments and will report the direct URL of the attachment and the model it was attached to (issue, merge request, issue note, etc) in the log. These attachments can be downloaded via the browser and re-uploaded to GitHub after the migration. </br></br> **NOTE (August, 11th 2022)**: Image attachments can no longer be migrated. The functionality of fetching images via personal access tokens has also been recently deprecated. GitLab doesn't seem to mention of this change in their deprecation or removal change logs, and nothing in the release notes for their releases.  |
| Tags | **Y** | Imported as "Releases" |
| Avatars | **N** | Avatars are not supported by `ghe-migrator` and are not currently on the roadmap for the GitLab Exporter |
| Commit Comments | **Y** | |
| Wikis | **Y** | |
| Milestones | **Y** | Since GitLab Milestones can be assigned to multiple Projects, we duplicate the Milestone for all associated Repositories |

## Known Issues / Limitations
This section describes in more detail some limitations of GitLab Exporter. Most models have a 1:1 mapping in GitHub Enterprise but there are a few models that don't translate over well.

#### Merge Request Notes
GitLab does not provide enough information in their API to properly recreate merge request diff notes as line comments in GitHub. Due to this limitation, diff notes are created in-line as comments in pull requests.

#### Fork Relationships
GitHub currently does not support migrating forks between GitLab and GitHub Enterprise due to the complexity in managing fork relationships to optimize disk usage. In addition, GitLab uses an entirely different ref structure that is not compatible with GitHub. For these reasons, fork relationships do not carry over when exporting and importing forked repositories from GitLab.

Users can create new forks once parent repositories are imported to GitHub and push their changes from their local forks to the new remotes on GitHub. An example may look like:

```
cd ~/my-forked-repo
git remote add github https://github.example.com/dpmex4527/my-forked-repo.git
git push --mirror github
```

Alternatively, a user could replace the `origin` remote (which would be GitLab)

```
cd ~/my-forked-repo
git remote set-url origin https://github.example.com/dpmex4527/my-forked-repo.git
git push --mirror origin
```

#### Events

GitLab Events do not expose enough information in their API to create valid events in GitHub. Events are imported as regular comments.

![A label application event imported as a comment](https://user-images.githubusercontent.com/12524137/28956148-d9fd4d44-78f3-11e7-8d67-20bd7b543d99.png)

#### Attachments
GitLab [announced](https://about.gitlab.com/2018/11/28/security-release-gitlab-11-dot-5-dot-1-released/) changes to their API that now enforce personal access tokens to work only with API, RSS, and registry resources. This change has broken how we download non-image attachments as we can no longer retrieve them via personal access token. This affects all GitLab versions from `11.5.1`, `11.4.8`, and `11.3.11` and onward, including GitLab.com. `gl-exporter` will skip exporting any unreachable non-image attachments and will report the direct URL of the attachment and the model it was attached to (issue, merge request, issue note, etc) in the log. These attachments can be downloaded via the browser and re-uploaded to GitHub after the migration.

#### Branch Protection Rules

GitLab Branch Protection Rules are predominately *access-based branch control* (e.g. "Allow to merge/push" by a team). This is a **different behaviour** to GitHub Branch Protecton Rules where they are *conditional-based branch control* (e.g. Require <*fulfilling a condition*> before <*action*>).

Rules behaviours and semantics are different between GitLab and GitHub products. During migration, GitLab Branch Protection Rules will create GitHub teams and associate each team to the branches. Upon editing the migrated branch protection rule itself, it will appear empty because there is no corresponding GitLab mechanism to migrate over.
