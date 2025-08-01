# Setup Guide

When using this codebase to migrate repos in your own organization, here are a few things that will need to be created/modified:

## Variables & Secrets

Create these [variables](https://docs.github.com/en/actions/learn-github-actions/variables#creating-configuration-variables-for-a-repository) and [secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) on the repository that is hosting this migration utility according to the table above.

See [Variable and Secret Automation](#variable-secret-script) for a script to automate the creation of variables and secrets.

There are several migration workflows that can be used to migrate repositories from various sources to GitHub.com. Each workflow is configured to migrate repositories from a specific source to a specific target. The following table lists the available workflows and their configurations.

| Issue Template Name | Workflow Name | Source | Target | Vars | Secrets | Notes |
|---------------|---------------|--------|--------|-------|-------|-------|
| GitLab to GitHub migration | `.github/workflows/migration-gitlab.yml` | GitLab Server | GitHub.com | SOURCE_ADMIN_USERNAME SOURCE_HOST TARGET_ORGANIZATION | SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |
| GitLab to GitHub migration [GEI] | `.github/workflows/migration-gitlab-to-ghec-gei.yml` | GitLab | GitHub.com | TARGET_ORGANIZATION TARGET_HOST SOURCE_ADMIN_USERNAME SOURCE_HOST GITHUB_STORAGE AWS_REGION AZURE_STORAGE_ACCOUNT BLOB_STORAGE_CONTAINER GL_EXPORTER_IMAGE DOCKER_REGISTRY_USERNAME | TARGET_ADMIN_TOKEN SOURCE_ADMIN_TOKEN AZURE_STORAGE_ACCESS_KEY AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY DOCKER_REGISTRY_PASSWORD | |

> [!NOTE]
> - \* When source is **GHES 3.7 and earlier** you need to define blob storage for GEI. To use Azure blob storage, define `AZURE_STORAGE_CONNECTION_STRING`. To use AWS blob storage, define `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, and `AWS_BUCKET_NAME`.
> - ** When source is GHES, you need to define `SOURCE_HOST`.
> - *** For GEI, you can set `INSTALL_PREREQS` to `false` to opt out of installing GEI and other prerequisites during the workflow run. If the variable is unset, it defaults to `true`.
> - **** For GEI with BitBucket Server, `BITBUCKET_ARCHIVE_DOWNLOAD_HOST` is only needed it using BBS Data Center cluster or if using a load balancer. `BITBUCKET_SHARED_HOME` can be set if your BitBucket Server is not using the default shared home directory.
> - For GEI with GitLab, `BLOB_STORAGE_CONTAINER` is used as the container name for Azure Storage or the bucket name for AWS S3.
> - **Container Image Configuration**: For GitLab migrations, you can use a custom container image by setting `GL_EXPORTER_IMAGE` (the container image URL), `DOCKER_REGISTRY_USERNAME` (username for private registries), and `DOCKER_REGISTRY_PASSWORD` (password for private registries). If these are not set, the workflow will use a default container and install prerequisites during execution.
> - Token requirements:
>   - **`SOURCE_ADMIN_TOKEN`** must have the `repo` and `admin:org` scopes set (for GitHub-based sources)
>   - **`TARGET_ADMIN_TOKEN`** must have the `admin:org`, `workflow` (if GEI), and `delete_repo` scopes set.

### Variable Secret Script

Review the following files:

- [.env.variables](.env.variables) - For Variables
- [.env.example](.env.example) - For Secrets Example

Once you have decided based on the chart above which variable and secrets you need to create, copy the `.env.example` and create your own `.env`. Then you can use the [setup-vars-and-secrets.sh](setup-vars-and-secrets.sh) script to automate the process.

To learn how to use the script run:

```bash
./setup-vars-and-secrets.sh -h
```

## Issue Labels

Verify that the [bootstrap actions](.github/workflows/bootstrap.yml) ran successfully as it creates the necessary issue labels. If not, create the following [issue labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels#creating-a-label):

1. `migration` (for all)
4. `gitlab` (for gitlab)
10. `gei-gitlab` (for GitLab to GitHub.com with GEI)

## SSH Key setup

### Runner Setup

If necessary, update the self-hosted runner label in your workflow so that it picks up the designated runner - the runner label otherwise defaults to `self-hosted`. Runners need to the following software installed:

- curl, wget, unzip, ssh, jq, git
- For GEI migrations:
  - `pwsh` is also required for GEI migrations
  - By default, these are installed during the workflow run, but can be disabled by setting the repo variable `INSTALL_PREREQS` to `false`

### Note on GEI Migrations

- Ensure that the `SOURCE_ADMIN_TOKEN` and `TARGET_ADMIN_TOKEN` tokens have the [appropriate PAT scopes](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/managing-access-for-a-migration-between-github-products#required-scopes-for-personal-access-tokens) for running a migration or has been [granted the migrator role](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/managing-access-for-a-migration-between-github-products#granting-the-migrator-role)

### Note on GitLab Exports

Working through the `gl-exporter` ruby runtime [requirements](/tools/gl-exporter/docs/Requirements.md) can sometimes be tricky. It's possible to build and push the [Dockerfile](/tools/gl-exporter/Dockerfile) to the repository and run as a container job:

#### Option 1: Default Container (Automatic Prerequisites Installation)
If you don't specify container variables, the workflow will use a default container and automatically install GitHub CLI, Go, and other prerequisites during execution.

#### Option 2: Custom Container Image
You can use a custom container image that has all prerequisites pre-installed. This approach is faster and more reliable:

1. Build your custom container image with GitLab exporter, GitHub CLI, Go, and gh-glx-migrator extension pre-installed
2. Push the image to a container registry (can be private)
3. Configure the following repository variables:
   - `GL_EXPORTER_IMAGE`: Your custom container image URL (e.g., `ghcr.io/your-org/gl-exporter:latest`)
   - `DOCKER_REGISTRY_USERNAME`: Username for accessing private registries (if needed)
4. Configure the following repository secret:
   - `DOCKER_REGISTRY_PASSWORD`: Password/token for accessing private registries (if needed)

Example workflow configuration:
```yml
jobs:
  migrate:
    name: Migrate GitLab Repository
    runs-on: ${{ inputs.RUNNER }}
    container:
      image: ${{ vars.GL_EXPORTER_IMAGE }}
      credentials:
        username: ${{ vars.DOCKER_REGISTRY_USERNAME }}
        password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
```

When using a custom container with all prerequisites pre-installed, you can set the `INSTALL_PREREQS` input to `false` to skip the installation steps and improve performance.
