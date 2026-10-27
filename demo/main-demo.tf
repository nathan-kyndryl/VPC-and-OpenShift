# ===========================================================================
# DEMO / LOW-COST MAIN — "skinflint cheap" edition
#
# Key differences from the production config (../main.tf):
#   • Single availability zone (zone-1 only)
#   • 1 worker node on bx2.2x8 (2 vCPU / 8 GB) vs 6 × bx2.4x16
#   • No dedicated LB subnets — Ingress LB lands on the worker subnet
#   • VPC flow logs disabled by default
#   • No addons block (kept minimal; add back via variables-demo.tf if needed)
#
# Estimated cost:  ~$150/mo  |  ~$0.21/hr  |  <$2 for a 10-hour demo day
# ===========================================================================

# ---------------------------------------------------------------------------
# 1. Resource Group
# ---------------------------------------------------------------------------

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.6.1"

  resource_group_name          = var.resource_group_name == null ? "${var.prefix}-rg" : null
  existing_resource_group_name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# 2. Cloud Object Storage
#    Used only for OpenShift internal image registry storage.
#    First 25 GB is free — more than enough for a demo.
# ---------------------------------------------------------------------------

module "cos" {
  source  = "terraform-ibm-modules/cos/ibm"
  version = "11.1.5"

  resource_group_id    = module.resource_group.resource_group_id
  region               = var.region
  resource_tags        = var.resource_tags
  access_tags          = var.access_tags

  cos_instance_name    = "${var.prefix}-cos"

  create_cos_bucket    = true
  bucket_name          = "${var.prefix}-registry"
  bucket_region        = var.region
  bucket_storage_class = "smart"
}

# ---------------------------------------------------------------------------
# 3. Single-Zone VPC
#    • 1 zone, 1 worker subnet with a public gateway
#    • No LB subnet — saves ~$0/mo (subnets are free) but keeps the layout
#      simple; the auto-created Ingress LB uses the worker subnet
#    • Flow logs disabled (var.enable_vpc_flow_logs defaults to false)
# ---------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-ibm-modules/landing-zone-vpc/ibm"
  version = "10.1.5"

  name              = var.vpc_name
  region            = var.region
  resource_group_id = module.resource_group.resource_group_id
  prefix            = var.prefix
  resource_tags     = var.resource_tags
  access_tags       = var.access_tags

  subnets = var.subnets

  # Only 1 public gateway — one zone, one PGW (~$3.60/mo vs $11 for three).
  use_public_gateways = {
    zone-1 = true
  }

  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules                        = []
    }
  ]

  network_cidrs = ["10.0.0.0/8"]

  # Flow logs off by default — avoids COS write charges.
  enable_vpc_flow_logs              = var.enable_vpc_flow_logs
  existing_cos_instance_guid        = module.cos.cos_instance_guid
  existing_storage_bucket_name      = var.enable_vpc_flow_logs ? module.cos.bucket_name : null
  create_authorization_policy_vpc_to_cos = var.enable_vpc_flow_logs

  clean_default_sg_acl = true
}

# ---------------------------------------------------------------------------
# 4. OpenShift (ROKS) Cluster — minimal demo sizing
#    • 1 worker node (bx2.2x8: 2 vCPU / 8 GB)
#    • Single zone — no multi-zone LB, no zone spreading
#    • Registry backed by the COS bucket above
#    • cluster_ready_when = "IngressReady" — wait for a usable endpoint
# ---------------------------------------------------------------------------

module "openshift" {
  source  = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version = "4.1.0"

  cluster_name      = "${var.prefix}-${var.cluster_name}"
  region            = var.region
  resource_group_id = module.resource_group.resource_group_id
  resource_tags     = var.resource_tags
  access_tags       = var.access_tags

  vpc_id      = module.vpc.vpc_id
  vpc_subnets = module.vpc.subnet_detail_map

  ocp_version = var.ocp_version

  worker_pools = var.worker_pools

  disable_public_endpoint = var.disable_public_endpoint

  pod_subnet_cidr     = var.pod_subnet_cidr
  service_subnet_cidr = var.service_subnet_cidr

  enable_registry_storage = true
  use_existing_cos        = true
  existing_cos_id         = module.cos.cos_instance_id
  cos_name                = module.cos.cos_instance_name

  attach_ibm_managed_security_group = true

  cluster_ready_when = "IngressReady"
}
