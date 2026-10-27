#!/usr/bin/env bash
# =============================================================================
# demo-up.sh — Spin up the OCP demo environment on IBM Cloud
#
# What this script does:
#   1. Checks that required tools are installed (ibmcloud CLI, terraform, oc/kubectl)
#   2. Installs the IBM Cloud Kubernetes Service CLI plugin if missing
#   3. Logs into IBM Cloud using your API key
#   4. Runs terraform init + plan + apply inside the demo/ directory
#   5. Downloads the kubeconfig so you can immediately use oc / kubectl
#   6. Prints the Ingress hostname and a cost reminder
#
# Usage:
#   chmod +x demo-up.sh
#   ./demo-up.sh
#
# Required env vars (or edit the CONFIG section below):
#   IBMCLOUD_API_KEY   — your IBM Cloud API key
#   IC_REGION          — IBM Cloud region (default: us-south)
#
# Estimated cost: ~$0.21/hr — run ./demo-down.sh when you're done.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIG — override with env vars or edit here
# -----------------------------------------------------------------------------
REGION="${IC_REGION:-us-south}"
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/demo" && pwd)"
TFVARS_FILE="${DEMO_DIR}/terraform.tfvars"
TFVARS_EXAMPLE="${DEMO_DIR}/terraform.tfvars.demo.example"

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
info "Checking required tools..."

command -v ibmcloud >/dev/null 2>&1 || \
  error "ibmcloud CLI not found. Install it from https://cloud.ibm.com/docs/cli"

command -v terraform >/dev/null 2>&1 || \
  error "terraform not found. Install it from https://developer.hashicorp.com/terraform/install"

if command -v oc >/dev/null 2>&1; then
  KUBE_CMD="oc"
elif command -v kubectl >/dev/null 2>&1; then
  KUBE_CMD="kubectl"
else
  warn "Neither 'oc' nor 'kubectl' found. Kubeconfig will be downloaded but you won't be able to verify nodes."
  KUBE_CMD=""
fi

success "Tool checks passed."

# -----------------------------------------------------------------------------
# 2. IBM Cloud Kubernetes Service plugin
# -----------------------------------------------------------------------------
if ! ibmcloud plugin list | grep -q "container-service\|kubernetes-service"; then
  info "Installing IBM Cloud Kubernetes Service plugin..."
  ibmcloud plugin install container-service -f
else
  success "container-service plugin already installed."
fi

# -----------------------------------------------------------------------------
# 3. API key check
# -----------------------------------------------------------------------------
if [[ -z "${IBMCLOUD_API_KEY:-}" ]]; then
  # Check if it's already set in terraform.tfvars
  if grep -q 'ibmcloud_api_key\s*=\s*"<YOUR_IBM_CLOUD_API_KEY>"' "${TFVARS_FILE}" 2>/dev/null; then
    error "IBMCLOUD_API_KEY is not set and terraform.tfvars still has the placeholder.\n       Set the env var:  export IBMCLOUD_API_KEY=your_key\n       or edit ${TFVARS_FILE}"
  fi
  if [[ ! -f "${TFVARS_FILE}" ]]; then
    error "IBMCLOUD_API_KEY env var is not set and ${TFVARS_FILE} does not exist.\n       Run:  cp ${TFVARS_EXAMPLE} ${TFVARS_FILE}\n       Then edit ${TFVARS_FILE} and set ibmcloud_api_key."
  fi
  # Extract the key from tfvars for the ibmcloud login step
  IBMCLOUD_API_KEY=$(grep 'ibmcloud_api_key' "${TFVARS_FILE}" | sed 's/.*=\s*"\(.*\)"/\1/')
fi

export IBMCLOUD_API_KEY

# -----------------------------------------------------------------------------
# 4. terraform.tfvars setup
# -----------------------------------------------------------------------------
if [[ ! -f "${TFVARS_FILE}" ]]; then
  info "No terraform.tfvars found — copying from example..."
  cp "${TFVARS_EXAMPLE}" "${TFVARS_FILE}"
  warn "Copied ${TFVARS_EXAMPLE} → ${TFVARS_FILE}"
  warn "Edit ${TFVARS_FILE} to set your ibmcloud_api_key, then re-run this script."
  exit 1
fi

if grep -q '<YOUR_IBM_CLOUD_API_KEY>' "${TFVARS_FILE}"; then
  error "terraform.tfvars still contains the placeholder API key.\n       Edit ${TFVARS_FILE} and replace <YOUR_IBM_CLOUD_API_KEY> with your real key."
fi

# -----------------------------------------------------------------------------
# 5. IBM Cloud login
# -----------------------------------------------------------------------------
info "Logging into IBM Cloud (region: ${REGION})..."
ibmcloud login --apikey "${IBMCLOUD_API_KEY}" -r "${REGION}" -q
success "Logged in to IBM Cloud."

# -----------------------------------------------------------------------------
# 6. Terraform init + plan + apply
# -----------------------------------------------------------------------------
info "Initialising Terraform in ${DEMO_DIR}..."
terraform -chdir="${DEMO_DIR}" init -upgrade -input=false

info "Running terraform plan..."
terraform -chdir="${DEMO_DIR}" plan -input=false -out=demo.tfplan

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  About to apply — estimated cost ~\$0.21/hr (~\$150/mo).${NC}"
echo -e "${YELLOW}  Run ./demo-down.sh when your demo is finished.${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

info "Applying Terraform plan (this takes ~30–45 min for the cluster)..."
terraform -chdir="${DEMO_DIR}" apply demo.tfplan

success "Terraform apply complete."

# -----------------------------------------------------------------------------
# 7. Download kubeconfig
# -----------------------------------------------------------------------------
CLUSTER_ID=$(terraform -chdir="${DEMO_DIR}" output -raw cluster_id 2>/dev/null || true)

if [[ -n "${CLUSTER_ID}" ]]; then
  info "Downloading kubeconfig for cluster: ${CLUSTER_ID}..."
  ibmcloud ks cluster config --cluster "${CLUSTER_ID}"
  success "Kubeconfig merged into ~/.kube/config"

  if [[ -n "${KUBE_CMD}" ]]; then
    info "Verifying worker nodes..."
    ${KUBE_CMD} get nodes
  fi
else
  warn "Could not read cluster_id from Terraform outputs. Run manually:"
  warn "  ibmcloud ks cluster config --cluster <your-cluster-id>"
fi

# -----------------------------------------------------------------------------
# 8. Summary
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Demo environment is ready!${NC}"
echo ""
terraform -chdir="${DEMO_DIR}" output 2>/dev/null || true
echo ""
echo -e "${YELLOW}  ⚠  Remember to tear down when done:  ./demo-down.sh${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
