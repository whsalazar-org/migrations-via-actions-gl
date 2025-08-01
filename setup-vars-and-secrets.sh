#!/bin/bash

set -e

# This script is used to create variables and secrets in a GitHub repository
# It supports container image configuration for GitLab migrations:
# - GL_EXPORTER_IMAGE: Custom container image URL (optional)
# - DOCKER_REGISTRY_USERNAME: Username for private registries (optional)
# - DOCKER_REGISTRY_PASSWORD: Password for private registries (optional, secret)
usage() {
  echo "Usage: $0 -s <server or host> -r <repository>"
  echo
  echo "This script uses the GitHub CLI to create variables and secrets in a GitHub repository"
  echo "It will use the default cli environment to interact with your repository"
  echo "If you want to use a different repository, you can specify the host and repository"
  echo "Options:"
  echo "  -s   Specify the server name / host Ex. github.example.com"
  echo "  -r   Specify the repository Ex. Owner/repo"
  exit 1
}

while getopts s:r: flag
do
    case "${flag}" in
        s) host=${OPTARG};;
        r) repository=${OPTARG};;
        *) usage ;;
    esac
done

if [ -n "$host" ]; then
   repository="$host/$repository"
fi

if [ -n "$repository" ]; then
  echo "Repository: $repository"
fi

auth_status=$(gh auth status)

check_empty_vars() {
  for file in .env .env.variables; do
    while IFS= read -r line; do
      if [[ $line == "#"* || -z $line ]]; then
        continue
      fi
      var_name=${line%%=*}
      var_value=${line#*=}
      if [[ -z $var_value ]]; then
        echo "Empty variable found in $file: $var_name"
        exit 1
      fi
    done < "$file"
  done
}

create_vars_and_secrets() {
  echo "Creating variables"
  gh variable set -f .env.variables -R $repository
  
  echo "Creating secrets"
  gh secret set -f .env -R $repository
}

if ! gh auth status > /dev/null 2>&1 ; then 
    echo $auth_status
    exit 1  
else
  check_empty_vars
  create_vars_and_secrets
fi

