#!/bin/bash

# shellcheck disable=SC2164
cd "$(dirname "$0")/.."

# Build the Go binary
go build -o gh-glx-exportor .

# Install the extension
gh extension install .
