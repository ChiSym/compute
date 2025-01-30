#!/usr/bin/env bash

set -euo pipefail

SCRIPTS_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPTS_DIR/common.sh"

# Default values
ZONE="us-west1-a"

# Function to get Project ID from Project Name
get_project_id() {
  local project_name="$1"
  local project_id

  project_id=$(gcloud projects list --filter="name=${project_name}" --format="value(projectId)")

  if [[ -z "$project_id" ]]; then
    error_exit "Failed to find project ID for project name: $project_name"
  fi

  echo "$project_id"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --instance-name)
      INSTANCE_NAME="$2"
      shift 2
      ;;
    --zone)
      ZONE="$2"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --machine-type)
      MACHINE_TYPE="$2"
      shift 2
      ;;
    --accelerator)
      ACCELERATOR="$2"
      shift 2
      ;;
    *)
      error_exit "Unknown option: $1"
      ;;
  esac
done

# Ensure required parameters are set
if [[ -z "${INSTANCE_NAME-}" || -z "${PROJECT_NAME-}" || -z "${MACHINE_TYPE-}" || -z "${ACCELERATOR-}" ]]; then
  error_exit "Usage: $0 --instance-name <name> --project-name <project_name> --machine-type <type> --accelerator <type=count> [--zone <zone>]"
fi

# Get Project ID from Project Name
PROJECT_ID=$(get_project_id "$PROJECT_NAME")

gcp-auth() {
  gcloud auth login \
    --project="$PROJECT_ID" \
    --update-adc --force ||
    error_exit "Failed to authenticate gcloud."
}

create-user-vm() {
  info "Bootstrapping new $INSTANCE_NAME..."

  gcp-auth

  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --image-family="common-cu123-ubuntu-2204-py310" \
    --image-project="deeplearning-platform-release" \
    --maintenance-policy=TERMINATE \
    --boot-disk-size=400GB \
    --boot-disk-type=pd-standard \
    --machine-type="$MACHINE_TYPE" \
    --accelerator="type=$ACCELERATOR,count=1" \
    --metadata="install-nvidia-driver=True" ||
    error_exit "Failed to create GCP instance."

  gcloud compute config-ssh --project "$PROJECT_ID" || error_exit "Failed to configure SSH."

  info "Your VM $INSTANCE_NAME.$ZONE.$PROJECT_ID is ready"
}

create-user-vm
