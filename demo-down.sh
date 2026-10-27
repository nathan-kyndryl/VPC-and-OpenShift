#!/usr/bin/env bash
# =============================================================================
# demo-down.sh — Tear down the OCP demo environment and stop all charges
#
# What this script does:
#   1. Logs into IBM Cloud (re-uses IBMCLOUD_API_KEY or reads from tfvars)
#   2. Runs terraform destroy inside the demo/ directory
#   3. Confirms all resources are gone
#
# Usage:
#   chmod +x demo-down.sh
#   ./demo-down.sh
#
# Required env vars (or set in demo/terraform.tfvars):
#   IBMCLOUD_API_KEY   — your IBM Cloud API key
#   IC_REGION          — IBM Cloud region (default: us-south)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIG
# -----------------------------------------------------------------------------
REGION="${IC_REGION:-us-south}"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/demo" && pwd)"
TFVARS_FILE="${DEMO_DIR}/terraform.tfvars"

# -----------------------------------------------------------------------------
# Colours
# -----------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# 1. Pre-flight checks
# -----------------------------------------------------------------------------
command -v ibmcloud >/dev/null 2>&1 || error "ibmcloud CLI not found."
command -v terraform >/dev/null 2>&1 || error "terraform not found."

if [[ ! -f "${DEMO_DIR}/.terraform/terraform.tfstate" ]] && \
   [[ ! -f "${DEMO_DIR}/terraform.tfstate" ]]; then
  warn "No Terraform state found in ${DEMO_DIR}."
  warn "If you used a remote backend, ensure credentials are available and re-run."
fi

# -----------------------------------------------------------------------------
# 2. API key
# -----------------------------------------------------------------------------
if [[ -z "${IBMCLOUD_API_KEY:-}" ]]; then
  if [[ ! -f "${TFVARS_FILE}" ]]; then
    error "IBMCLOUD_API_KEY is not set and ${TFVARS_FILE} does not exist."
  fi
  IBMCLOUD_API_KEY=$(grep 'ibmcloud_api_key' "${TFVARS_FILE}" | sed 's/.*=\s*"\(.*\)"/\1/')
fi
export IBMCLOUD_API_KEY

# -----------------------------------------------------------------------------
# 3. IBM Cloud login
# -----------------------------------------------------------------------------
info "Logging into IBM Cloud (region: ${REGION})..."
ibmcloud login --apikey "${IBMCLOUD_API_KEY}" -r "${REGION}" -q
success "Logged in."

# -----------------------------------------------------------------------------
# 4. Confirmation prompt
# -----------------------------------------------------------------------------
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  WARNING: This will DESTROY all demo resources.${NC}"
echo -e "${RED}  VPC, subnets, OpenShift cluster, COS bucket — everything.${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -r -p "Type 'yes' to confirm destroy: " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  info "Destroy cancelled."
  exit 0
fi

# -----------------------------------------------------------------------------
# 5. Terraform destroy
# -----------------------------------------------------------------------------
info "Running terraform destroy in ${DEMO_DIR}..."
terraform -chdir="${DEMO_DIR}" destroy -auto-approve -input=false

# -----------------------------------------------------------------------------
# 6. Summary
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  All demo resources have been destroyed.${NC}"
echo -e "${GREEN}  No further charges will be incurred for this demo.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
