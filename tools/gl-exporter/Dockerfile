# Based on an image of 'ruby' that contains prerequisities and packages preinstalled, build
# a Docker image containing 'gl-exporter' and its dependencies.
#
# Source is maintained at:
#
#   https://github.com/github/gl-exporter
#
# Run and interact with container (without proxy):
#
#   $ docker run -it github/gl-exporter /bin/bash
#
# Run and interact with container (with proxy):
#
#   $ docker run -it -e http_proxy='http://proxy.company.com:8080' -e https_proxy='http://proxy.company.com:8080' github/gl-exporter /bin/bash
#

FROM ruby:3.2.1
LABEL Maintainer="GitHub Services <services@github.com>"
LABEL Description="gl-exporter is a tool for exporting GitLab repositories to be imported by ghe-migrator."

# Run updates
RUN apt-get update -qqy
RUN apt-get upgrade -qqy

# Install packages
RUN apt-get -qqy --no-install-recommends install cmake nano

# Get gl-exporter
COPY ./ /gl-exporter/
WORKDIR /gl-exporter

# Install bundler
RUN gem install --no-document bundler

# Run bootstrap
RUN chmod +x script/bootstrap
RUN script/bootstrap

# Create workspace to use gl-exporter
WORKDIR /workspace

ENV PATH=/gl-exporter/exe:$PATH

CMD ["gl_exporter"]
