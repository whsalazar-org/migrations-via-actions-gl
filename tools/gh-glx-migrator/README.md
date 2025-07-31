# GitHub GitLab Migration Tool (gh-glx-migrator)

A GitHub CLI extension tool is a GitHub CLI extension for migrating repositories from GitLab to GitHub Enterprise with Data Residency. This tool helps manage the migration process, using S3 storage, Azure Blob Storage, and GitHub Blob Storage.

glx-migrator will handle the following:

- Exporting repositories from GitLab using [gl-exporter](https://github.com/github/gl-exporter/tree/master)
- Uploading the repositories to S3/GitHub Blob Storage/Azure Blob Storage
- Creating migration sources
- Starting the migration process
- Monitoring the migration process
- Cleaning up the migration process

## Requirements

### Development Tools

- Go 1.23 or later
- Docker 24.0 or later
- Docker Compose v2.21 or later
- GitHub CLI 2.0 or later
- Make

### Operating System Support

- macOS (Intel/Apple Silicon)
- Linux (x86_64/arm64)
- Windows (via WSL2)

## Installation

1. Install the GitHub CLI first:

   ```sh
   # Follow instructions at https://cli.github.com
   ```

2. Install the GitHub CLI extension:

   ```sh
   cd gh-glx-migrator
   go build . # Build to latest binary
   gh extension install .
   ```

## Required Environment Variables

Before using the tool, set up the following environment variables:

### GitHub Enterprise with Data Residency Configuration

```bash
export GITHUB_PAT=<your-github-token>
export GITHUB_API_ENDPOINT=<github-enterprise-url>  # optional, default: api.github.com
export GITHUB_ORG=<your-github-org>
```

### GitHub Enterprise Cloud Configuration

```bash
export GITHUB_GHEC_PAT=<your-github-token>
```

### GitLab Configuration

```bash
export GITLAB_PAT=<your-gitlab-token>
export GITLAB_API_ENDPOINT=<gitlab-api-url>  # optional, default: gitlab.com/api/v4
export GITLAB_USERNAME=<your-gitlab-username>
export GITLAB_HOST=<gitlab-url>  # e.g. https://gitlab.com
```

### AWS Blob Storage Configuration

```bash
export AWS_ACCESS_KEY_ID=<your-aws-access-key>
export AWS_SECRET_ACCESS_KEY=<your-aws-secret-key>
export AWS_REGION=<aws-region>  # e.g. us-west-2
export AWS_BUCKET=<bucket-name>  # Optional, can be specified via command flags
```

### Azure Blob Storage Configuration

```bash
export AZURE_STORAGE_ACCOUNT=<your-azure-storage-account>
export AZURE_STORAGE_ACCESS_KEY=<your-azure-storage-access-key>
```

### GitHub Blob Storage Configuration

```bash
export USE_GITHUB_STORAGE=true
```

- `GITHUB_TOKEN`: A GitHub Personal Access Token with the necessary permissions to create repositories on the target GitHub Enterprise instance.
- `GITHUB_URL`: The URL of the target GitHub Enterprise with Data Residency instance.
- `GITHUB_ORG`: The name of the GitHub organization to use for the migration.
- `GITHUB_GHEC_PAT`: A GitHub Personal Access Token with the necessary permissions to create repositories on the target GitHub Enterprise Cloud instance.
- `GITLAB_TOKEN`: A GitLab Personal Access Token with the necessary permissions to read repositories on the source GitLab instance.
- `GITLAB_URL`: The URL of the source GitLab instance.
- `GITLAB_API_URL`: The URL of the GitLab API. This is usually the same as `GITLAB_URL`, but can be different in some cases.
- `GITLAB_USERNAME`: The username of the GitLab account to use for the migration.
- `AWS_BUCKET`: The name of the S3 bucket to use for blob storage.
- `AWS_ACCESS_KEY_ID`: The access key ID for the S3 bucket.
- `AWS_SECRET_ACCESS_KEY`: The secret access key for the S3 bucket.
- `AWS_REGION`: The region of the S3 bucket.
- `AZURE_STORAGE_ACCOUNT`: The name of the Azure storage account to use for blob storage.
- `AZURE_STORAGE_ACCESS_KEY`: The access key to use for accessing the Azure storage account.
- `USE_GITHUB_STORAGE`: Set to true if using GitHub owned blob storage.

## Usage

The tool is organized into subcommands. Run `gh glx-migrator --help` to see the list of available subcommands.

### Verify Configuration

checks that the environment variables are set up correctly.

```sh
gh glx-migrator verify
```

### AWS Operations

#### Generate AWS Pre-Signed URL

Generates a pre-signed URL for the specified S3 blob. This can be used to upload or download a file to/from the S3 bucket.

```sh
# Basic usage
gh glx-migrator generate-aws-presigned-url --bucket <bucket-name> --blob-name <blob-name>

# With custom duration
gh glx-migrator generate-aws-presigned-url --bucket <bucket-name> ---blob-name <blob-name> --duration 30m
```

Options:

- `--bucket`: The name of the S3 bucket. Optional, or use `AWS_BUCKET` env var.
- `--blob-name`: The file path and name in S3.
- `--duration`: The duration in minutes for which the URL is valid. The default is 30 minutes.

#### Upload to AWS S3

Uploads a file to the specified S3 bucket.

```sh
# Basic usage
gh glx-migrator upload-to-s3 --bucket <bucket-name> --blob-name <blob-name> --archive-file-path <archive-file-path>
```

Options:

- `--bucket`: The name of the S3 bucket. Optional, or use `AWS_BUCKET` env var.
- `--blob-name`: The file path and name in S3. Optional, default to local file name.
- `--archive-file-path`: The path to the migration archive file.

### Azure Operations

#### Upload to Azure blob storage

Uploads a file to Azure blob storage and generates a SAS URL.

```sh
gh glx-migrator upload-to-azure --container <blob-storage-container> --blob-name <blob-name> --archive-file-path <archive-file-path> --duration <sas-url-duration>
```

Options:

- `--container`: The name of the azure blob storage container.
- `--blob-name`: The name fo the blob to create in the azure storage container. Optional, default to local file name.
- `--archive-file-path`: The path to the migration archive file.
- `--duration`: The duration in minutes for which the URL is valid. The default is 30 minutes.

### GitLab Operations

#### Export GitLab Repositories

This step generates an export archive from a GitLab project using the [gl‑exporter](https://github.com/github/gl-exporter/tree/master) Docker image. **Prerequisites:**

- Ensure Docker is installed on your host.
- Clone and build the [gl‑exporter](https://github.com/github/gl-exporter/tree/master) Docker image if you have not already:
  
  ```bash
  git clone --depth=1 --branch=master https://github.com/github/gl-exporter.git
  cd gl-exporter
  docker build --no-cache=true -t github/gl-exporter .
  docker tag github/gl-exporter github/gl-exporter
  ```

   > **Note:** The `--no-cache=true` flag is used to ensure the latest changes are included in the build. This can be omitted if you are building the image for the first time.

- Use the `glx export-archive` command to generate an export archive from a GitLab project.
  - Using the `--gl-namespace` and `--gl-project` options, specify the GitLab project to export.

      ```sh
      gh glx-migrator export-archive --gl-namespace <project-namespace> --gl-project <project-name> --output-file <filename>
      ```

  - Using CSV file, specify the GitLab project to export.

      ```sh
      gh glx-migrator export-archive --csv-file <filename> --output-file <filename>
      ```

   Options:

  - `--csv-file`: The name of the CSV file containing the list of GitLab projects to export.
  - `--gl-namespace`: The namespace of the GitLab project to export. This should be in the format `<namespace>`.
  - `--gl-project`: The path of the GitLab project to export. This should be in the format `<project-name>`.
  - `--output-file`: The name of the output file.

### GitHub Operations

#### Get Organization Information

Gets information about the GitHub organization.

```sh
gh glx-migrator get-org-info --org <organization-name>
```

Options:

- `--org`: The name of the GitHub organization.

#### Create Migration Source

Creates a migration source for the specified repository.

```sh
gh glx-migrator create-migration-source --owner <owner-id> --name <source-name>
```

Options:

- `--owner`: The owner ID of the repository.
- `--name`: The name of the migration source.

#### Start Migration

Starts the migration for the specified repository.

```sh
gh glx-migrator migrate \
  --migration-source-id <source-id> \
  --org-owner-id <owner-id> \
  --source-repo <gitlab-repo-url> \
  --archive-url <s3-archive-url> \
  --visibility <private|internal|public> \
  --repo-name <repo-name>
```

Options:

- `--migration-source-id`: The ID of the migration source.
- `--org-owner-id`: The owner ID of the repository.
- `--source-repo`: The URL of the GitLab repository to migrate.
- `--archive-url`: The URL of the S3 archive file.
- `--visibility`: The visibility of the destination repository.
- `--repo-name`: The name of the destination repository.

### Unified Operations

This command combines both AWS and GitHub operations to provide an easier path for migration.  

```sh
gh glx import-archive \
      --archive-file-path migration_archive.tar.gz \
      --source-repo https://gitlab.com/org/repo \
      --bucket s3bucket \
      --blob-name migration_archive.tar.gz \
      --duration 20 \
      --org org \
      --visibility private \
      --repo-name my-repo
```

Currently this command does the following:

1. Upload migration archive to AWS S3 or Azure blob storage.
2. Creates a presigned url for the archive in AWS S3 or Azure blob storage.
3. Gets the org id of the destination org.
4. Creates a migration source.
5. Starts the migration and monitors the progress.
6. Delete the migration archive from AWS S3 or Azure blob storage.

Options:

- `--archive-file-path`: The path to the migration archive file.
- `--source-repo`: The GitLab source url of the repo.
- `-bucket`: S3 bucket where the archive is uploaded to. Optional, or use `AWS_BUCKET` env var.
- `--blob-name`: The Name to use for blob in S3 or Azure. Optional, default is filename parsed from `--archive-file-path` arg.
- `--duration`: Duration for the presigned URL in minutes. Optional, defaults to 30 minutes.
- `--org`: The destination org for the repo.
- `--visibility`: The visibility of the destination repo. Optional, defaults to `private`.
- `--repo-name`: The name of the destination repo. Optional, defaults to repo name parsed from `--source-repo` arg.

The `import-archive` command will decide to upload to AWS S3, Azure blob storage or GitHub owned blob storage based on the environment variables present. To use AWS S3, define `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables. To use Azure blob storage, define `AZURE_STORAGE_ACCOUNT` and `AZURE_STORAGE_ACCESS_KEY` environment variables. To use Github owned blob storage, define `USE_GITHUB_STORAGE` and set the value to `true`.

**Note:** When using Azure blob storage, set the `--bucket` argument value to the name of your azure storage container.

### Help

#### Examples

```sh
# Get help for the top-level command
gh glx-migrator --help
```

## Migration Process

1. Verify Configuration

   ```sh
   gh glx-migrator verify
   ```

2. Export GitLab Repositories

   ```sh
   gh glx-migrator export-archive --gl-namespace <namespace> --gl-project <project> --output-file <filename>
   ```

3. Upload Archive to S3

   ```sh
   gh glx-migrator upload-to-s3 --bucket <bucket-name> --blob-name <blob-name> --archive-file-path <archive-file-path>
   ```

4. Create Pre-Signed URL

   ```sh
   gh glx-migrator generate-aws-presigned-url --bucket <bucket-name> --blob-name <blob-name>
   ```

5. Get Organization Information

   ```sh
   gh glx-migrator get-org-info --org <organization-name>
   ```

6. Create Migration Source

   ```sh
   gh glx-migrator create-migration-source --owner O_xxxx --name "GitLab Migration"
   ```

7. Start Migration

   ```sh
   gh glx-migrator migrate \
   --migration-source-id <source-id> \
   --org-owner-id <owner-id> \
   --source-repo <gitlab-repo-url> \
   --archive-url <s3-archive-url> \
   --visibility <private|internal|public> \
   --repo-name <repo-name>
   ```

## Development

To run the tool locally, you can build the binary and run it directly.

### Available Make Commands

```sh
# Show all available commands
make help

# Build the binary
make build

# Build for all platforms
make build-all

# Run tests
make test

# Run linter
make lint

# Build Docker image
make docker-build

# Run Docker container
make docker-run

# Run with Docker Compose
make docker-compose

# Set up development environment
make dev

# Create a new release
make release TAG=v1.0.0
```

### Build the Binary

```sh
make build
```

### Run the Tool

```sh
./bin/gh-glx --help
```

### Run the Tool with `go run`

You can also run the tool using `go run`:

```sh
go run main.go --help
```

### Docker Usage

### Build and Run with Docker

1. Build the image:

   ```sh
   docker build -t gh-glx-migrator .
   ```

2. Run with environment variables:

   ```sh
   docker run -it --rm \
   -e GITHUB_PAT=<your-github-token> \
   -e GITHUB_API_ENDPOINT=<github-enterprise-url> \
   -e GITHUB_ORG=<your-github-org> \
   -e GITLAB_PAT=<your-gitlab-token> \
   -e GITLAB_API_ENDPOINT=<gitlab-api-url> \
   -e GITLAB_USERNAME=<your-gitlab-username> \
   -e GITLAB_HOST=<gitlab-url> \
   -e AWS_ACCESS_KEY_ID=<your-aws-access-key> \
   -e AWS_SECRET_ACCESS_KEY=<your-aws-secret-key> \
   -e AWS_REGION=<aws-region> \
   -e AWS_BUCKET=<bucket-name> \
   gh-glx-migrator
   ```

### Using Docker Compose

1. Create a `.env` file with your environment variables
2. Run with docker-compose:

   ```sh
   docker compose up
   ```

This containerization setup:

1. Uses multi-stage build to minimize image size
2. Includes GitHub CLI installation
3. Verifies environment variables on startup
4. Provides both Docker and Docker Compose options
5. Configures GitHub CLI authentication automatically
6. Maintains all functionality of the CLI tool in a containerized environment
7. The Docker image is based on Alpine Linux for minimal size while maintaining full functionality.

The Docker image is based on Alpine Linux for minimal size while maintaining full functionality.

## Contributing

[fork]: https://github.com/github/REPO/fork
[pr]: https://github.com/github/REPO/compare
[style]: https://github.com/github/REPO/blob/main/.golangci.yaml

Hi there! We're thrilled that you'd like to contribute to this project. Your help is essential for keeping it great.

Contributions to this project are [released](https://help.github.com/articles/github-terms-of-service/#6-contributions-under-repository-license) to the public under the [project's open source license](LICENSE).

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

### Prerequisites for running and testing code

These are one time installations required to be able to test your changes locally as part of the pull request (PR) submission process.

1. install Go [through download](https://go.dev/doc/install) | [through Homebrew](https://formulae.brew.sh/formula/go)
2. [install golangci-lint](https://golangci-lint.run/usage/install/#local-installation)

### Submitting a pull request

1. Create a new branch: `git checkout -b my-branch-name`
2. Configure and install the dependencies: `script/bootstrap`
3. Make sure the tests pass on your machine: `go test -v ./...`
4. Make sure linter passes on your machine: `golangci-lint run`
5. Make your change, add tests, and make sure the tests and linter still pass
6. Push to your [fork] and [submit a pull request][pr]
7. Pat yourself on the back and wait for your pull request to be reviewed and merged.

Here are a few things you can do that will increase the likelihood of your pull request being accepted:

- Follow the [style guide][style].
- Write tests.
- Keep your change as focused as possible. If there are multiple changes you would like to make that are not dependent upon each other, consider submitting them as separate pull requests.
- Write a [good commit message](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

### Resources

- [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)
- [Using Pull Requests](https://help.github.com/articles/about-pull-requests/)
- [GitHub Help](https://help.github.com)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
