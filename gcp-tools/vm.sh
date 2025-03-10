#!/usr/bin/env bash

set -euo pipefail

SCRIPTS_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPTS_DIR/common.sh"

# Default values
ZONE="us-west1-a"

# Function to display usage
usage() {
  echo "Usage: $0 <action> [--instance-name <name>] [--project-name <project_name>] [--machine-type <type>] [--accelerator <type=count>] [--zone <zone>]"
  echo "Actions:"
  echo "The create, start, stop, and delete actions require --project-name and --instance-name"
  echo "  create  - Create a new VM using"
  echo "  start   - Start an existing VM"
  echo "  stop    - Stop a running VM"
  echo "  delete  - Delete a VM"
  echo "  list    - List all VMs for supplied --project-name"
  echo "  help  - Show this help message"
  exit 0
}

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

# Function to get Zone for an instance
get_instance_zone() {
  local instance_name="$1"
  local project_id="$2"
  local zone

  zone=$(gcloud compute instances list --filter="name=${instance_name}" --project=${project_id} --format="value(zone)")

  if [[ -z "$zone" ]]; then
    error_exit "Failed to find zone for instance: $instance_name"
  fi

  echo "$zone"
}

# Function to authenticate only if needed
gcp-auth() {
  local current_project
  current_project=$(gcloud config get-value project 2>/dev/null || echo "")
  
  if [[ "$current_project" != "$PROJECT_ID" ]]; then
    info "Authenticating for project $PROJECT_ID..."
    gcloud auth login \
      --project="$PROJECT_ID" \
      --update-adc ||
      error_exit "Failed to authenticate gcloud."
  else
    info "Already authenticated for project $PROJECT_ID. Skipping authentication."
  fi
}

# Ensure action is provided as the first argument
if [[ $# -lt 1 ]]; then
  usage
fi

ACTION="$1"
shift

if [[ "$ACTION" == "help" ]]; then
  usage
fi

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

# Ensure required parameters are set based on action
if [[ "$ACTION" != "list" && (-z "${PROJECT_NAME-}" || -z "${INSTANCE_NAME-}") ]]; then
  error_exit "Usage: $0 <action> --project-name <project_name> --instance-name <name>"
fi

# Get Project ID from Project Name
PROJECT_ID=$(get_project_id "$PROJECT_NAME")

if [[ -z "$ZONE" && "$ACTION" != "list" ]]; then
  ZONE=$(get_instance_zone "$INSTANCE_NAME" "$PROJECT_ID")
fi

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

start-vm() {
  info "Starting VM $INSTANCE_NAME and configuring SSH..."
  gcloud compute instances start "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT_ID" || error_exit "Failed to start VM."
  gcloud compute config-ssh --project "$PROJECT_ID" || error_exit "Failed to configure SSH."
}

stop-vm() {
  info "Stopping VM $INSTANCE_NAME..."
  gcloud compute instances stop "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT_ID" || error_exit "Failed to stop VM."
}

delete-vm() {
  info "Deleting VM $INSTANCE_NAME..."
  gcloud compute instances delete "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT_ID" --quiet || error_exit "Failed to delete VM."
}

list-vms() {
  info "Listing VMs for project $PROJECT_ID..."
  gcloud compute instances list --project "$PROJECT_ID"
}

case "$ACTION" in
  create)
    create-user-vm
    ;;
  start)
    start-vm
    ;;
  stop)
    stop-vm
    ;;
  delete)
    delete-vm
    ;;
  list)
    list-vms
    ;;
  *)
    error_exit "Invalid action specified. Use <create|start|stop|delete|list|help> as the first argument."
    ;;
esac
