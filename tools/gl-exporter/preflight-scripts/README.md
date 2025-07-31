# GitLab Exporter Pre-flight Script

This script will ensure that your migration environment is suited to run the GitLab Exporter utility. The utility runs best on Unix-based operating systems (such as macOS or Linux), so this script will only run in environments with bash. You may satisfy the dependencies in Windows, but it is a little bit harder to do, and this script cannot verify that it will work.

## What this script does

- Checks to make sure git, ruby, and cmake are installed
- Checks to make sure Ruby version is exactly `3.2.1`, or see [`.ruby-version`](../.ruby-version) for details
- Ensures Ruby's `bundler` gem is installed
- Verifies that you have proper API credentials
- Verifies that you have access to a repository you are cloning

## Usage

### Download the script to your migration environment

```shell
curl -O https://github.com/github/gl-exporter/blob/master/preflight-scripts/preflight/raw
```

### Add executable permissions

```shell
chmod +x preflight
```

### Execute directly

```shell
./preflight
```

## Explanation of prompts

#### GitLab Host

A full domain pointing to your GitLab instance without a trailing slash, e.g. `https://gitlab.example.com`

#### GitLab API Private Token

The API token from GitLab for the user who will be performing the migration. Found at https://gitlab.example.com/profile/account

#### Example GitLab Project SSH clone path

The SSH clone path for a project you will be exporting from GitLab. This verifies connectivity and authorization. Please note that the GitLab Exporter utility uses only the default SSH key from your system and cannot be customized.
