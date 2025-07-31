#!/bin/bash
set -e

# Verify required environment variables
required_vars=(
    "GITHUB_PAT"
    "GITHUB_API_ENDPOINT"
    "GITHUB_ORG"
    "GITLAB_PAT"
    "GITLAB_API_ENDPOINT"
    "GITLAB_USERNAME"
    "GITLAB_HOST"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_REGION"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Required environment variable $var is not set"
        exit 1
    fi
done

# Configure GitHub CLI
echo "hosts:
  ${GITHUB_API_ENDPOINT}:
    oauth_token: ${GITHUB_PAT}
    git_protocol: https" > /root/.config/gh/hosts.yml

exec "$@"