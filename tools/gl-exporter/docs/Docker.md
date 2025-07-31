# Using Docker with gl-exporter

The purpose of this document is to provide step-by-step instructions on using building and using a gl-exporter Docker image to import into GitHub Enterprise.

## Prerequisites

- **Docker is installed on your host machine**. For instructions on how to install docker, see the [official installation docs](https://docs.docker.com/engine/installation/).
- **DNS/Name Resolution.** If your Docker host has difficulty with name resolution (i.e. DNS), edit your `/etc/hosts` file
with the IP addresses of both your **GitLab** and **GitHub Enterprise** servers. One way to test if name resolution is working is checking to see if you can resolve the name to the GitLab server you will run the export against:

    ```bash
    $ nslookup gitlab.host.com
    ```

- **Authentication to GitHub and GitLab.** You will need each of the following during the process:
    - GitLab [Access Token](https://docs.gitlab.com/ce/user/profile/personal_access_tokens.html)
    - GitHub Enterprise [Personal Access Token](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) with the `admin` scope

## Build docker image
To build the `gl-exporter` docker image, run the following commands:

  ```bash
  $ git clone --depth=1 --branch=master https://github.com/github/gl-exporter.git
  $ cd ./gl-exporter
  $ docker build --no-cache=true -t github/gl-exporter .
  $ docker tag github/gl-exporter github/gl-exporter
  ```

## Export from GitLab

The following is a list of steps to help you run the `github/gl-exporter` image on your Docker host. **Be sure you completed the [Prerequisites](#Prerequisites) section above.**

1. Run the docker image in interactive mode:

    ```bash
    $ docker run -it github/gl-exporter /bin/bash
    ```

1. Set two environment variables to connect to your GitLab host. In the first variable, replace
`gitlab.example.com` with your GitLab hostname. In the second variable, paste your GitLab Private Token:

    ```bash
    $ export GITLAB_API_ENDPOINT=https://gitlab.example.com/api/v4
    $ export GITLAB_USERNAME=<gitlab-username>
    $ export GITLAB_API_PRIVATE_TOKEN=<hidden>
    ```
    > **Note** 
    > For exporting from cloud GitLab, the API url is `https://gitlab.com/api/v4`

1. Create a CSV file with a list of the GitLab Group,Repository you would like to export. **For example:**

    ```bash
    $ echo "GroupOne,RepoOne" >> export.csv
    $ echo "GroupOne,RepoTwo" >> export.csv
    $ echo "GroupTwo,RepoThree" >> export.csv
    ```
    > **Note**
    > In the example with a GitLab repository URL of `https://gitlab.com/abc/xyz`, the group is `abc` and the repository is `xyz`

1. Now, **run the export** using your newly created CSV file:

    ```bash
    $ gl_exporter -f export.csv -o migration-archive.tar.gz
    ```

1. Once the `gl_exporter` process is completed, from the Docker host, run `docker cp` to copy the archive file out of the container:

    ```bash
    $ docker cp <container-id>:/workspace/migration-archive.tar.gz .
    ```
    > **Note**
    > Use `$ docker container ls` to obtain the Container ID

    > **Note**
    > As an alternative to `docker cp`, can also use a [bind mount](https://docs.docker.com/get-started/06_bind_mounts/) to mount a local directory into the container

## Import into GitHub Enterprise Cloud

Several options for importing migration archive to GitHub Enterprise Cloud

1. `ghec-importer`
2. [Enterprise Cloud Importer (ECI)](https://github.github.com/enterprise-migrations/#/./3.1.1-import-from-archive) using web browser
3. [GraphQL](https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api) manually (`ghec-importer` is a wrapper around the GraphQL)

## Import into GitHub Enterprise Server 

1. See the [Migrating data to GitHub Enterprise Server](https://docs.github.com/en/migrations/using-ghe-migrator/migrating-data-to-github-enterprise-server) docs for using `ghe-migrator` to migrate data to GitHub Enterprise Server

Happy migrating! 🎉
