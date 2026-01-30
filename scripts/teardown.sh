#!/usr/bin/env bash
# teardown.sh -- Delete firewall rules, subnet, and VPC network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Tear down infrastructure created by setup.sh: delete firewall rules, subnet,
and VPC network. Requires confirmation unless --yes is passed.

Does NOT disable APIs (harmless to leave enabled, and disabling can break
other resources in the project).

Options:
  --project NAME        GCP project              (default: cr-limit-tests)
  --region REGION       GCP region               (default: europe-west1)
  --network NAME        VPC network              (default: limit-checker-vpc)
  --subnet NAME         Subnet                   (default: limit-checker-subnet)
  --fw-target NAME      Firewall rule: target    (default: allow-cloudrun-to-target)
  --fw-iap NAME         Firewall rule: IAP SSH   (default: allow-iap-ssh)
  --yes, -y             Skip confirmation prompt
  -h, --help            Show this help
EOF
}

parse_flags "$@"
ensure_project

# ── Check what exists ────────────────────────────────────────────────────────
FW_IAP_EXISTS=false
FW_TARGET_EXISTS=false
SUBNET_EXISTS=false
NETWORK_EXISTS=false

if gcloud compute firewall-rules describe "$FW_RULE_IAP" \
     --format='value(name)' &>/dev/null; then
  FW_IAP_EXISTS=true
fi

if gcloud compute firewall-rules describe "$FW_RULE_TARGET" \
     --format='value(name)' &>/dev/null; then
  FW_TARGET_EXISTS=true
fi

if gcloud compute networks subnets describe "$SUBNET" \
     --region="$REGION" --format='value(name)' &>/dev/null; then
  SUBNET_EXISTS=true
fi

if gcloud compute networks describe "$NETWORK" \
     --format='value(name)' &>/dev/null; then
  NETWORK_EXISTS=true
fi

if [[ "$FW_IAP_EXISTS" != "true" ]] && \
   [[ "$FW_TARGET_EXISTS" != "true" ]] && \
   [[ "$SUBNET_EXISTS" != "true" ]] && \
   [[ "$NETWORK_EXISTS" != "true" ]]; then
  ok "Nothing to tear down"
  exit 0
fi

# ── Confirmation ─────────────────────────────────────────────────────────────
if [[ "$YES" != "true" ]]; then
  echo ""
  echo "This will delete:"
  if [[ "$FW_IAP_EXISTS" == "true" ]]; then
    echo "  - Firewall rule: ${FW_RULE_IAP}"
  fi
  if [[ "$FW_TARGET_EXISTS" == "true" ]]; then
    echo "  - Firewall rule: ${FW_RULE_TARGET}"
  fi
  if [[ "$SUBNET_EXISTS" == "true" ]]; then
    echo "  - Subnet: ${SUBNET} (region: ${REGION})"
  fi
  if [[ "$NETWORK_EXISTS" == "true" ]]; then
    echo "  - VPC network: ${NETWORK}"
  fi
  echo ""
  read -rp "Continue? [y/N] " confirm
  if [[ "$confirm" != [yY] ]]; then
    info "Aborted"
    exit 0
  fi
fi

# ── Step 1: Delete firewall rule -- IAP SSH ──────────────────────────────────
if [[ "$FW_IAP_EXISTS" == "true" ]]; then
  info "Deleting firewall rule: ${FW_RULE_IAP}"
  if gcloud compute firewall-rules delete "$FW_RULE_IAP" --quiet; then
    ok "Deleted firewall rule: ${FW_RULE_IAP}"
  else
    err "Failed to delete firewall rule: ${FW_RULE_IAP}"
  fi
fi

# ── Step 2: Delete firewall rule -- Cloud Run → target ───────────────────────
if [[ "$FW_TARGET_EXISTS" == "true" ]]; then
  info "Deleting firewall rule: ${FW_RULE_TARGET}"
  if gcloud compute firewall-rules delete "$FW_RULE_TARGET" --quiet; then
    ok "Deleted firewall rule: ${FW_RULE_TARGET}"
  else
    err "Failed to delete firewall rule: ${FW_RULE_TARGET}"
  fi
fi

# ── Step 3: Delete subnet ────────────────────────────────────────────────────
if [[ "$SUBNET_EXISTS" == "true" ]]; then
  info "Deleting subnet: ${SUBNET}"
  if gcloud compute networks subnets delete "$SUBNET" \
       --region="$REGION" --quiet; then
    ok "Deleted subnet: ${SUBNET}"
  else
    err "Failed to delete subnet: ${SUBNET}"
  fi
fi

# ── Step 4: Delete VPC network ───────────────────────────────────────────────
if [[ "$NETWORK_EXISTS" == "true" ]]; then
  info "Deleting VPC network: ${NETWORK}"
  if gcloud compute networks delete "$NETWORK" --quiet; then
    ok "Deleted VPC network: ${NETWORK}"
  else
    err "Failed to delete VPC network: ${NETWORK}"
  fi
fi

ok "Teardown complete"
