#!/bin/bash

# Import common functions
source common.sh

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    *)
      error_exit "Unknown parameter: $1"
      ;;
  esac
done

# Ensure PROJECT_ID is set
if [[ -z "$PROJECT_ID" ]]; then
  error_exit "--project-id parameter is required."
fi

info "Setting project to $PROJECT_ID"
gcloud config set project "$PROJECT_ID" || error_exit "Failed to set project ID"

info "Enabling Compute Engine API"
gcloud services enable compute.googleapis.com || error_exit "Failed to enable Compute Engine API"

info "Creating default network"
gcloud compute networks create default --subnet-mode=auto || error_exit "Failed to create default network"

info "Creating firewall rule: default-allow-internal"
gcloud compute firewall-rules create default-allow-internal \
    --network=default \
    --allow=tcp:0-65535,udp:0-65535,icmp \
    --source-ranges=10.128.0.0/9 || error_exit "Failed to create default-allow-internal firewall rule"

info "Creating firewall rule: default-allow-icmp"
gcloud compute firewall-rules create default-allow-icmp \
    --network=default \
    --allow=icmp \
    --source-ranges=0.0.0.0/0 || error_exit "Failed to create default-allow-icmp firewall rule"

info "Creating firewall rule: default-allow-rdp"
gcloud compute firewall-rules create default-allow-rdp \
    --network=default \
    --allow=tcp:3389 \
    --source-ranges=0.0.0.0/0 || error_exit "Failed to create default-allow-rdp firewall rule"

info "Creating firewall rule: default-allow-ssh"
gcloud compute firewall-rules create default-allow-ssh \
    --network=default \
    --allow=tcp:22 \
    --source-ranges=0.0.0.0/0 || error_exit "Failed to create default-allow-ssh firewall rule"

info "Setup completed successfully"
