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

# Function to write to S3
write_to_s3() {
    # Parsing the YAML file
    S3_BUCKET=$(cat "${CONFIG_FILE}" | yq -r '.s3_bucket_name')
    PATHS=$(cat "${CONFIG_FILE}" | yq -r '.paths[]')
    FORMULAE=$(cat "${CONFIG_FILE}" | yq -r '.formulae')

    # Check if paths and formulae are empty
    if [ -z "$PATHS" -a "$FORMULAE" = "false" ]; then
        echo "No paths to sync and no formulae to install. No action taken."
        exit 0
    fi

    # Upload each file to S3
    for path in $PATHS; do
        eval path=$path
        if [ -d "$path" ]; then
            aws s3 cp --recursive "$path" s3://${S3_BUCKET}/$(basename $path)
        else
            aws s3 cp "$path" s3://${S3_BUCKET}/$(basename $path)
        fi
    done

    # If formulae are enabled, get the list of Homebrew formulae and upload to S3

    brew list --formulae -1 > /tmp/formulae.txt
    aws s3 cp /tmp/formulae.txt s3://${S3_BUCKET}/formulae.txt

    brew list --casks -1 > /tmp/casks.txt
    aws s3 cp /tmp/casks.txt s3://${S3_BUCKET}/casks.txt
}

# Function to read from S3
read_from_s3() {
    # Parsing the YAML file
    S3_BUCKET=$(cat "${CONFIG_FILE}" | yq -r '.s3_bucket_name')
    PATHS=$(cat "${CONFIG_FILE}" | yq -r '.paths[]')
    FORMULAE=$(cat "${CONFIG_FILE}" | yq -r '.formulae')

    # Check if paths and formulae are empty
    if [ -z "$PATHS" -a "$FORMULAE" = "false" ]; then
        echo "No paths to sync and no formulae to install. No action taken."
        exit 0
    fi

    # Download each file from S3
    for path in $PATHS; do
        eval path=$path
        if [ -d "$path" ]; then
            aws s3 cp --recursive s3://${S3_BUCKET}/$(basename $path) $path
        else
            aws s3 cp s3://${S3_BUCKET}/$(basename $path) $path
        fi
    done

    # If formulae are enabled, get the list of Homebrew formulae from S3 and install them
    if [ "$FORMULAE" = "true" ]; then
        aws s3 cp s3://${S3_BUCKET}/formulae.txt /tmp/formulae.txt
        while read formula; do
            brew install $formula
        done < /tmp/formulae.txt

        aws s3 cp s3://${S3_BUCKET}/casks.txt /tmp/casks.txt
        while read formula; do
            brew install $formula
        done < /tmp/casks.txt
    fi
}

echo "starting execution of $(date '+%Y-%m-%d %H:%M:%S')"

# Deciding on mode based on the command line arguments
case $MODE in
    read) read_from_s3 ;;
    write) write_to_s3 ;;
    *) echo "Invalid mode selected" ;;
esac
