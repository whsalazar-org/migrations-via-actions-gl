#!/bin/bash

CONFIG_FILE="config.json"

declare -A SOURCES
SOURCES=(
  ["AzureDevOps"]="ado"
  ["BitBucket"]="bbs"
  ["GitLab"]="gl"
  ["GitHubEnterpriseServer"]="ghes"
  ["GitHubEnterpriseCloud"]="ghec"
)

declare -A DESTINATIONS
DESTINATIONS=(
  ["GitHubEnterpriseCloud(GEI)"]="ghec-gei"
  ["GitHubEnterpriseCloud(ECI)"]="ghec-eci"
  ["GitHubEnterpriseServer"]="ghes"
)

echo "Select the source:"
select OPTION in "${!SOURCES[@]}"; do
  if [[ -n $OPTION ]]; then
    SOURCE=${SOURCES[$OPTION]}
    break
  else
    echo "Invalid option"
  fi
done

while true; do
  echo "Select the destination:"
  select OPTION in "${!DESTINATIONS[@]}"; do
    if [[ -n $OPTION ]]; then
      DESTINATION=${DESTINATIONS[$OPTION]}
      # Check if the SOURCE-to-DESTINATION key exists in the config file
      if jq -e ".\"$SOURCE-to-$DESTINATION\"" $CONFIG_FILE > /dev/null; then
        echo "Source to destination: $SOURCE-to-$DESTINATION"
        break 2
      else
        echo "Invalid source/destination pair. Please try again."
        break
      fi
    else
      echo "Invalid option"
    fi
  done
done


# Get the list of files and folders to keep from the configuration file
ISSUE_TEMPLATES=$(jq -r ".\"$SOURCE-to-$DESTINATION\".issue_templates[]" $CONFIG_FILE)
WORKFLOWS=$(jq -r ".\"$SOURCE-to-$DESTINATION\".workflows[]" $CONFIG_FILE)
TOOLS=$(jq -r ".\"$SOURCE-to-$DESTINATION\".tools[]" $CONFIG_FILE)

# Convert the lists to arrays
ISSUE_TEMPLATES_ARRAY=($ISSUE_TEMPLATES)
WORKFLOWS_ARRAY=($WORKFLOWS)
TOOLS_ARRAY=($TOOLS)

# Convert the arrays of necessary items into strings, with each item separated by a newline
ISSUE_TEMPLATES_STRING=$(printf "%s\n" "${ISSUE_TEMPLATES_ARRAY[@]}")
WORKFLOWS_STRING=$(printf "%s\n" "${WORKFLOWS_ARRAY[@]}")
TOOLS_STRING=$(printf "%s\n" "${TOOLS_ARRAY[@]}")

git checkout -b temp/$SOURCE-to-$DESTINATION-bootstrap-$(date +%s)

# Loop over all files and folders in the .github/ISSUE_TEMPLATE directory
for ITEM in .github/ISSUE_TEMPLATE/*; do
  # Get the filename from the ITEM variable
  FILENAME=$(basename "$ITEM")
  # If the filename is not in the list of necessary files, delete it
  if ! echo "$FILENAME" | grep -Fxq "$ISSUE_TEMPLATES_STRING"; then
    echo "removing $ITEM"
    rm -rf "$ITEM"
  fi
done

# Loop over all files and folders in the .github/workflows directory
for ITEM in .github/workflows/*; do
  # Get the filename from the ITEM variable
  FILENAME=$(basename "$ITEM")
  # If the filename is not in the list of necessary files, delete it
  if ! echo "$FILENAME" | grep -Fxq "$WORKFLOWS_STRING"; then
    echo "removing $ITEM"
    rm -rf $ITEM
  fi
done

# Loop over all files and folders in the tools directory
for ITEM in tools/*; do
  # Get the filename from the ITEM variable
  FILENAME=$(basename "$ITEM")
  # If the filename is not in the list of necessary files, delete it
  if ! echo "$FILENAME" | grep -Fxq "$TOOLS_STRING"; then
    echo "removing $ITEM"
    rm -rf $ITEM
  fi
done