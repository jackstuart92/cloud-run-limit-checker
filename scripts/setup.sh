#!/usr/bin/env bash
# setup.sh -- Create VPC, subnet, and firewall rules (idempotent).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Create all infrastructure prerequisites: enable APIs, create VPC network,
subnet, and firewall rules. All operations are idempotent.

Options:
  --project NAME        GCP project              (default: cr-limit-tests)
  --region REGION       GCP region               (default: europe-west1)
  --network NAME        VPC network              (default: limit-checker-vpc)
  --subnet NAME         Subnet                   (default: limit-checker-subnet)
  --subnet-range CIDR   Subnet IP range          (default: 10.0.0.0/20)
  --fw-target NAME      Firewall rule: target    (default: allow-cloudrun-to-target)
  --fw-iap NAME         Firewall rule: IAP SSH   (default: allow-iap-ssh)
  -h, --help            Show this help
EOF
}

parse_flags "$@"
ensure_project

# ── Step 1: Enable APIs ──────────────────────────────────────────────────────
info "Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  compute.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com \
  iap.googleapis.com \
  --quiet
ok "APIs enabled"

# ── Step 2: Create VPC network ───────────────────────────────────────────────
info "Ensuring VPC network: ${NETWORK}"
if gcloud compute networks describe "$NETWORK" \
     --format='value(name)' &>/dev/null; then
  ok "VPC network already exists"
else
  gcloud compute networks create "$NETWORK" \
    --subnet-mode=custom \
    --quiet
  ok "Created VPC network: ${NETWORK}"
fi

# ── Step 3: Create subnet ────────────────────────────────────────────────────
info "Ensuring subnet: ${SUBNET} (range: ${SUBNET_RANGE})"
if gcloud compute networks subnets describe "$SUBNET" \
     --region="$REGION" --format='value(name)' &>/dev/null; then
  ok "Subnet already exists"
else
  gcloud compute networks subnets create "$SUBNET" \
    --network="$NETWORK" \
    --region="$REGION" \
    --range="$SUBNET_RANGE" \
    --enable-private-ip-google-access \
    --quiet
  ok "Created subnet: ${SUBNET}"
fi

# ── Step 4: Create firewall rule -- Cloud Run → target ───────────────────────
info "Ensuring firewall rule: ${FW_RULE_TARGET}"
if gcloud compute firewall-rules describe "$FW_RULE_TARGET" \
     --format='value(name)' &>/dev/null; then
  ok "Firewall rule already exists: ${FW_RULE_TARGET}"
else
  gcloud compute firewall-rules create "$FW_RULE_TARGET" \
    --network="$NETWORK" \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:8080 \
    --source-ranges="$SUBNET_RANGE" \
    --target-tags=target-service \
    --quiet
  ok "Created firewall rule: ${FW_RULE_TARGET}"
fi

# ── Step 5: Create firewall rule -- IAP SSH ──────────────────────────────────
info "Ensuring firewall rule: ${FW_RULE_IAP}"
if gcloud compute firewall-rules describe "$FW_RULE_IAP" \
     --format='value(name)' &>/dev/null; then
  ok "Firewall rule already exists: ${FW_RULE_IAP}"
else
  gcloud compute firewall-rules create "$FW_RULE_IAP" \
    --network="$NETWORK" \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-tags=target-service \
    --quiet
  ok "Created firewall rule: ${FW_RULE_IAP}"
fi

ok "Setup complete"
