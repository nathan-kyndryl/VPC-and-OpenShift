# ---------------------------------------------------------------------------
# 1. Resource Group
# ---------------------------------------------------------------------------

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.6.1"

  # Re-use an existing group when provided, otherwise create a new one.
  resource_group_name          = var.resource_group_name == null ? "${var.prefix}-rg" : null
  existing_resource_group_name = var.resource_group_name
}

# ---------------------------------------------------------------------------
# 2. Cloud Object Storage
#    Used for:
#      • OpenShift internal image registry storage
#      • (Optional) VPC flow-log collector
# ---------------------------------------------------------------------------

module "cos" {
  source  = "terraform-ibm-modules/cos/ibm"
  version = "11.1.5"

  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  resource_tags     = var.resource_tags
  access_tags       = var.access_tags

  cos_instance_name = "${var.prefix}-cos"

  # Single bucket shared for the registry; add more buckets via the module's
  # `buckets` input if you want a separate flow-logs bucket.
  create_cos_bucket = true
  bucket_name       = "${var.prefix}-registry"
  bucket_region     = var.region
  bucket_storage_class = "smart"
}

# ---------------------------------------------------------------------------
# 3. Multi-Zone VPC + Subnets + Public Gateways
#    • 3 availability zones
#    • Worker subnets with public gateways (outbound internet)
#    • Load-balancer subnets (private)
#    • Default VPC ACL with IBM Cloud + VPC connectivity rules
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

  # --- Subnets (3 zones × 2 subnets each) --------------------------------
  subnets = var.subnets

  # Enable a public gateway in every zone so worker nodes can pull images.
  use_public_gateways = {
    zone-1 = true
    zone-2 = true
    zone-3 = true
  }

  # --- Network ACL --------------------------------------------------------
  network_acls = [
    {
      name                         = "vpc-acl"
      add_ibm_cloud_internal_rules = true
      add_vpc_connectivity_rules   = true
      prepend_ibm_rules            = true
      rules                        = []
    }
  ]

  # Supernets used when generating ACL rules for the cluster.
  network_cidrs = var.network_cidrs

  # --- VPC Flow Logs ------------------------------------------------------
  enable_vpc_flow_logs              = var.enable_vpc_flow_logs
  existing_cos_instance_guid        = module.cos.cos_instance_guid
  existing_storage_bucket_name      = var.enable_vpc_flow_logs ? module.cos.bucket_name : null
  create_authorization_policy_vpc_to_cos = var.enable_vpc_flow_logs

  # Clean the default security group / ACL so only explicit rules apply.
  clean_default_sg_acl = true
}

# ---------------------------------------------------------------------------
# 4. OpenShift (ROKS) Cluster
#    • Placed in the VPC above
#    • Worker pools spread across all 3 zones
#    • IBM-managed security group attached to every worker node
#    • Internal image registry backed by the COS bucket
#    • Cluster autoscaler and CSI storage drivers can be enabled via addons
# ---------------------------------------------------------------------------

module "openshift" {
  source  = "terraform-ibm-modules/base-ocp-vpc/ibm"
  version = "4.1.0"

  # --- Identity -----------------------------------------------------------
  cluster_name      = "${var.prefix}-${var.cluster_name}"
  region            = var.region
  resource_group_id = module.resource_group.resource_group_id
  resource_tags     = var.resource_tags
  access_tags       = var.access_tags

  # --- Network ------------------------------------------------------------
  vpc_id      = module.vpc.vpc_id
  vpc_subnets = module.vpc.subnet_detail_map

  # --- OCP version --------------------------------------------------------
  ocp_version = var.ocp_version

  # --- Worker pools -------------------------------------------------------
  worker_pools = var.worker_pools

  # --- Endpoint -----------------------------------------------------------
  # Set to true if a private-only cluster is required.
  disable_public_endpoint = var.disable_public_endpoint

  # --- Networking internals -----------------------------------------------
  pod_subnet_cidr     = var.pod_subnet_cidr
  service_subnet_cidr = var.service_subnet_cidr

  # --- Registry storage ---------------------------------------------------
  enable_registry_storage = true
  use_existing_cos        = true
  existing_cos_id         = module.cos.cos_instance_id
  cos_name                = module.cos.cos_instance_name

  # --- Add-ons ------------------------------------------------------------
  addons = var.addons

  # Attach the IBM-managed kube-<clusterid> security group to worker nodes.
  attach_ibm_managed_security_group = true

  # Block until the Ingress controller is ready (healthier default than master-only).
  cluster_ready_when = "IngressReady"
}
