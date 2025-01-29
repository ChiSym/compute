#!/usr/bin/env bash

set -euo pipefail

SCRIPTS_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPTS_DIR/common.sh"

# Default values
ZONE="us-west1-a"

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
    --project)
      PROJECT="$2"
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

# Required parameters are set
if [[ -z "${INSTANCE_NAME-}" || -z "${PROJECT-}" || -z "${MACHINE_TYPE-}" || -z "${ACCELERATOR-}" ]]; then
  error_exit "Usage: $0 --instance-name <name> --project <project> --machine-type <type> --accelerator <type=count> [--zone <zone>]"
fi

# Authenticate GCP
gcp-auth() {
  gcloud auth login \
    --project="$PROJECT" \
    --update-adc --force ||
    error_exit "Failed to authenticate gcloud."
}

create-user-vm() {
  info "Bootstrapping new $INSTANCE_NAME..."

  gcp-auth

  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --image-family="common-cu123-ubuntu-2204-py310" \
    --image-project="deeplearning-platform-release" \
    --maintenance-policy=TERMINATE \
    --boot-disk-size=400GB \
    --boot-disk-type=pd-standard \
    --machine-type="$MACHINE_TYPE" \
    --accelerator="type=$ACCELERATOR,count=1" \
    --metadata="install-nvidia-driver=True" \
    --create-disk="name=$INSTANCE_NAME-data,size=2048GB,type=pd-balanced,auto-delete=no" ||
    error_exit "Failed to create GCP instance."

  gcloud compute config-ssh --project "$PROJECT" || error_exit "Failed to configure SSH."

  info "Your VM $INSTANCE_NAME.$ZONE.$PROJECT is ready"
}

create-user-vm
