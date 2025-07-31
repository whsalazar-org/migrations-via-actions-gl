# GitLab Exporter

This is a utility written in Ruby that uses the GitLab API to export GitLab data in a format that is understandable by GitHub Enterprise's `ghe-migrator` utility. This serves the purpose of performing a high-fidelity migration of data from GitLab.com, GitLab CE, or GitLab EE to GitHub Enterprise.

For an explanation of what this utility can migrate, please read the [summary of features and limitations](docs/Features.md). To verify your installed software and GitLab permissions are sufficient to run this software, please check out the [preflight-check script](preflight-scripts/).

For an explanation of the minimum system requirements to run this utility, please read the [summary of GitLab Exporter Requirements](docs/Requirements.md).

> **Note** 
> This project is maintained by the [data portability team](https://github.com/github/data-portability).

## Installation

From the command line, run

    $ git clone https://github.com/github/gl-exporter.git
    $ cd gl-exporter
    $ script/bootstrap

## Usage

Set environment variables for connecting to GitLab.

    $ export GITLAB_API_ENDPOINT=https://gitlab.com/api/v4
    $ export GITLAB_USERNAME=someuser
    $ export GITLAB_API_PRIVATE_TOKEN=1234567890

> **Note** 
> The GitLab Exporter utility uses HTTP(S) authentication when cloning your respositories. It does not support SSH-based clones.

> **Note** 
> The GitLab Exporter utility is expecting a token from an administrator of the GitLab instance. If an administrator's token is not provided, "blocked" / "banned" users will not be able to be queried from the GitLab APIs and will result in a `undefined method `[]' for nil:NilClass (NoMethodError)` error.

Create an export archive by passing the namespace and project name for your GitLab project.

    $ gl_exporter --namespace gitlab-org --project gitlab-ce -o migration_archive.tar.gz

You can provide a [CSV file](./spec/fixtures/export_list.csv) with a list of namespaces and project names to export.

    $ gl_exporter -f path/to/export_list.csv -o migration_archive.tar.gz

To get a list of all projects on a GitLab instance, run `./bin/console` and enter this snippet (may take a while to run):

```ruby
projects = Gitlab.get("projects/all", auto_paginate: :standard).map do |project|
  project["path_with_namespace"].split("/").join(",")
end
File.open("projects.csv", "w") { |f| f.write projects.join("\n") }
```

### Usage with Docker

See our [docker](docs/Docker.md) guide on how to use docker to build and run `gl-exporter`.

### Locking projects

Before a final migration, you may want to automatically lock or archive your GitLab projects to prevent future commits being made on GitLab. Use the `--lock-projects` flag to lock your GitLab projects automatically.

    $ gl_exporter [...]  --lock-projects=true

Set `--lock-projects` to `transient` in order to lock the projects as soon as the export starts, but unlock them when the migration is complete. This can be useful for exporting data from a GitLab instance that is in use.

### Specifying models to export

If you want to selectively export certain models, use the `--except` or `--only` flag. Currently, the optional models are `merge_requests`, `issues`, `commit_comments`, `hooks`, and `wiki`.

    $ gl_exporter [...] --except merge_requests
    $ gl_exporter [...] --only issues,commit_comments

### Disable SSL verification

The utility will not validate SSL certificates against the certificate store if you provide the `--ssl-no-verify` flag

    $ gl_exporter [...] --ssl-no-verify

### Issue and Merge Request Renumbering

GitHub combines their Issue and Pull Request numbering sequence. For example, if you open a Pull Request in a new Repository, its number will be `1`. Then if an Issue is opened, that Issue number will be `2`.

In GitLab, the numbering sequences for Issues and Merge Requests are independent. The first Merge Request is number `1`, and the first Issue is number `1`.

To accommodate this, by default, this utility renumbers exported Issues and Merge Requests in the order that they were created, with the oldest being number `1`.

You can specify that either Merge Requests or Issues preserve their original numbers, then the other renumbered. This is helpful, for example, if you do not make much use of GitLab Issues, and would like to preserve the original numbers of Merge Requests. This way, imported Pull Requests will have the same number they had in GitLab, but Issues will have new numbers.

    $ gl_exporter [...] --without-renumbering=merge_requests
    $ gl_exporter [...] --without-renumbering=issues

## Development

After checking out the repo, follow the [installation](#installation) steps. Then, run `rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Read [these docs](https://bundler.io/guides/creating_gem.html) for information on creating a gem with Bundler.

### Generating documentation

Documentation is written with [YARD](http://yardoc.org/) and can be generated by running the `yardoc` command.

## Contributing

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant code of conduct](CODE_OF_CONDUCT.md).

Bug reports and pull requests are welcome on GitHub at https://github.com/github/gl-exporter. Check out our [Contribution Guide](CONTRIBUTING.md) to get you started.  
