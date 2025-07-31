# Bootstrap Script

## Description

This script is designed to facilitate the migration of repositories between different Git platforms. It uses a configuration file to determine the available source and destination platforms and the specific settings for each migration.

## Why to Use

Migrating repositories between different platforms can be a complex task to know which workflows and resources to use for each platform, especially when dealing with different platform configurations. This script automates the process and keeps only the files needed for your migration.

## How to Use

To use the script, follow these steps:

1. Open a terminal.
2. Navigate to the directory containing the script.
3. Run the script using the command `./bootstrap.sh`.
4. When prompted, select the source platform from the list.
5. Then, select the destination platform from the list.
6. The script will check the configuration file to ensure that the selected source/destination pair is valid. If it is, the script will proceed with the migration. If it isn't, it will ask you to select the destination again.

## Requirements

- Bash 4 or later.
- `jq` command-line JSON processor.
- A configuration file named `config.json` in the same directory as the script. The configuration file should be a JSON object where each key is a string in the format `SOURCE-to-DESTINATION` and each value is an object containing the settings for that migration.

## Configuration File

The `config.json` file is a JSON object that maps source/destination pairs to their migration settings. Each key should be a string in the format `SOURCE-to-DESTINATION`, where `SOURCE` and `DESTINATION` are the internal names of the source and destination platforms (e.g., `ado`, `bbs`, `gl`, `ghes`, `ghec-gei`, `ghec-eci`).

Each value should be an object containing the settings for that migration. The exact settings required will depend on the source and destination platforms.

Here's an example of what the `config.json` file might look like:

```json
{
  "ado-to-ghec-gei": {
    "issue_templates": ["bug_report.md", "feature_request.md"]
  },
  "bbs-to-ghec-eci": {
    "issue_templates": ["bug_report.md"]
  },
  "bbs-to-ghes": {
    "issue_templates": ["bug_report.md", "feature_request.md", "custom_template.md"]
  }
}