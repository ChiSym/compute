#!/bin/bash

# Import common functions
source common.sh

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

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    *)
      error_exit "Unknown parameter: $1"
      ;;
  esac
done

# Ensure PROJECT_NAME is set
if [[ -z "$PROJECT_NAME" ]]; then
  error_exit "--project-name parameter is required."
fi

# Get Project ID from Project Name
PROJECT_ID=$(get_project_id "$PROJECT_NAME")

info "Setting project to $PROJECT_ID"
gcloud config set project "$PROJECT_ID" 

info "Enabling Compute Engine API"
gcloud services enable compute.googleapis.com 

info "Creating default network"
gcloud compute networks create default --subnet-mode=auto 

info "Creating firewall rule: default-allow-internal"
gcloud compute firewall-rules create default-allow-internal \
    --network=default \
    --allow=tcp:0-65535,udp:0-65535,icmp \
    --source-ranges=10.128.0.0/9

info "Creating firewall rule: default-allow-icmp"
gcloud compute firewall-rules create default-allow-icmp \
    --network=default \
    --allow=icmp \
    --source-ranges=0.0.0.0/0

info "Creating firewall rule: default-allow-rdp"
gcloud compute firewall-rules create default-allow-rdp \
    --network=default \
    --allow=tcp:3389 \
    --source-ranges=0.0.0.0/0

info "Creating firewall rule: default-allow-ssh"
gcloud compute firewall-rules create default-allow-ssh \
    --network=default \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0

info "Setup completed successfully"
