#!/bin/bash

set -u
set -o pipefail

# AWS CLI and JQ are required
command -v aws >/dev/null 2>&1 || { echo >&2 "AWS CLI required but it's not installed.  Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "yq required but it's not installed.  Aborting."; exit 1; }

# Default mode and config file
MODE=""
CONFIG_FILE=""

# Handle command line arguments
while getopts "rwhf:" opt; do
  case $opt in
    r) MODE="read";;
    w) MODE="write";;
    f) CONFIG_FILE=$OPTARG;;
    h) echo "Usage: sync.sh [-r | -w] -f config_file"
       exit 0;;
    *) echo "Invalid option: -$OPTARG" >&2
       exit 1;;
  esac
done

# Exit if no arguments were provided
if [ -z "$MODE" -o -z "$CONFIG_FILE" ]; then
    echo "No mode or config file provided"
    exit 1
fi

# Parsing the YAML file
S3_BUCKET=$(cat "${CONFIG_FILE}" | yq -r '.s3_bucket_name')
PATHS=$(cat "${CONFIG_FILE}" | yq -r '.paths[]')
FORMULAE=$(cat "${CONFIG_FILE}" | yq -r '.formulae')

# Function to write to S3
write_to_s3() {
    # Check if paths and formulae are empty
    if [ -z "$PATHS" -a "$FORMULAE" = "false" ]; then
        echo "No paths to sync and no formulae to install. No action taken."
        exit 0
    fi

    # Upload each file to S3
    for path in $PATHS; do
        eval path=$path
        if [ -d "$path" ]; then
            aws s3 sync "$path" s3://${S3_BUCKET}/$(basename $path)
        else
            if [ "$(etag "$(basename "$path")")" = "$(md5sum "$path" | awk '{print $1}')" ]; then
                continue
            fi

            aws s3 cp "$path" s3://${S3_BUCKET}/$(basename $path)
        fi
    done

    # If formulae are enabled, get the list of Homebrew formulae and upload to S3
    if [ "$FORMULAE" = "true" ]; then
        brew list --formulae -1 > /tmp/formulae.txt
        if [ "$(etag formulae.txt)" != "$(md5sum /tmp/formulae.txt | awk '{print $1}')" ]; then
            aws s3 cp /tmp/formulae.txt s3://${S3_BUCKET}/formulae.txt
        fi

        brew list --casks -1 > /tmp/casks.txt
        if [ "$(etag casks.txt)" != "$(md5sum /tmp/casks.txt | awk '{print $1}')" ]; then
            aws s3 cp /tmp/casks.txt s3://${s3_bucket}/casks.txt
        fi
    fi
}

# Function to read from S3
read_from_s3() {
    # Check if paths and formulae are empty
    if [ -z "$PATHS" -a "$FORMULAE" = "false" ]; then
        echo "No paths to sync and no formulae to install. No action taken."
        exit 0
    fi

    # Download each file from S3
    for path in $PATHS; do
        eval path=$path
        if [ -d "$path" ]; then
            aws s3 sync s3://${S3_BUCKET}/$(basename $path) $path
        else
            if [ "$(etag "$(basename "$path")")" = "$(md5sum "$path" | awk '{print $1}')" ]; then
                continue
            fi
            aws s3 cp s3://${S3_BUCKET}/$(basename $path) $path
        fi
    done

    # If formulae are enabled, get the list of Homebrew formulae from S3 and install them
    if [ "$FORMULAE" = "true" ]; then
        brew list --formulae -1 > /tmp/formulae.txt
        if [ "$(etag formulae.txt)" != "$(md5sum /tmp/formulae.txt | awk '{print $1}')" ]; then
            aws s3 cp s3://${S3_BUCKET}/formulae.txt /tmp/formulae.txt
            while read formula; do
                brew install $formula
            done < /tmp/formulae.txt
        fi

        brew list --casks -1 > /tmp/casks.txt
        if [ "$(etag casks.txt)" != "$(md5sum /tmp/casks.txt | awk '{print $1}')" ]; then
            aws s3 cp s3://${S3_BUCKET}/casks.txt /tmp/casks.txt
            while read formula; do
                brew install $formula
            done < /tmp/casks.txt
        fi
    fi
}

# Outputs ETag, e.g. `414c10737f7cb371a0d161b7c20d265d`
etag() {
    aws s3api head-object --bucket "$S3_BUCKET" --key "$1" | jq -r .ETag | tr -d '"'
}

echo "starting execution of $(date '+%Y-%m-%d %H:%M:%S')"

# Deciding on mode based on the command line arguments
case $MODE in
    read) read_from_s3 ;;
    write) write_to_s3 ;;
    *) echo "Invalid mode selected" ;;
esac
