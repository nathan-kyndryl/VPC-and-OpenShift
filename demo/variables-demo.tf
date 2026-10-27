# ===========================================================================
# DEMO / LOW-COST CONFIGURATION
# Single zone · 1 worker node · bx2.2x8 · no flow logs · no LB subnet
# Estimated cost: ~$150/mo running continuously, ~$0.21/hr, <$2 for a day demo
# ===========================================================================

# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to authenticate with IBM Cloud."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region to deploy into (e.g. us-south, eu-de, jp-tok)."
  type        = string
  default     = "us-south"
}

variable "prefix" {
  description = "Prefix prepended to every resource name."
  type        = string
  default     = "ocp-demo"
}

variable "resource_tags" {
  description = "User tags applied to every resource."
  type        = list(string)
  default     = ["env:demo", "cost:minimal"]
}

variable "access_tags" {
  description = "IBM Cloud access-management tags."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of an existing resource group. null creates '<prefix>-rg'."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# VPC / Networking
# ---------------------------------------------------------------------------

variable "vpc_name" {
  description = "Base name for the VPC."
  type        = string
  default     = "vpc"
}

# Single zone, single worker subnet — no dedicated LB subnet needed for demos.
variable "subnets" {
  description = "Single-zone subnet layout. Override only if 10.10.10.0/24 conflicts."
  type = object({
    zone-1 = list(object({
      name           = string
      cidr           = string
      public_gateway = optional(bool, false)
      acl_name       = string
      no_addr_prefix = optional(bool, false)
    }))
  })
  default = {
    zone-1 = [
      { name = "worker-zone-1", cidr = "10.10.10.0/24", public_gateway = true, acl_name = "vpc-acl" }
    ]
  }
}

# Flow logs are disabled by default in the demo — avoids COS write charges.
variable "enable_vpc_flow_logs" {
  description = "Set to true to capture VPC flow logs (adds minor COS write cost)."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# OpenShift Cluster
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Base name for the OpenShift cluster."
  type        = string
  default     = "roks-demo"
}

variable "ocp_version" {
  description = "OpenShift version (e.g. 4.15). null = IBM Cloud default."
  type        = string
  default     = null
}

# bx2.2x8 = 2 vCPU / 8 GB — minimum viable for ROKS system pods.
# 1 worker × 1 zone = 1 node total.
variable "worker_pools" {
  description = "Worker pool definitions. Default is the smallest viable ROKS config."
  type = list(object({
    pool_name         = string
    machine_type      = string
    workers_per_zone  = number
    operating_system  = string
    subnet_prefix     = optional(string)
    labels            = optional(map(string))
    minSize           = optional(number)
    maxSize           = optional(number)
    enableAutoscaling = optional(bool)
    secondary_storage = optional(string)
    boot_volume_encryption_kms_config = optional(object({
      crk             = string
      kms_instance_id = string
      kms_account_id  = optional(string)
    }))
    additional_security_group_ids = optional(list(string))
  }))
  default = [
    {
      pool_name        = "default"
      machine_type     = "bx2.2x8"   # 2 vCPU / 8 GB — ~$55/mo
      workers_per_zone = 1            # 1 zone × 1 worker = 1 node total
      operating_system = "REDHAT_8_64"
      subnet_prefix    = "worker"
    }
  ]
}

variable "disable_public_endpoint" {
  description = "Set to true for a private-only cluster."
  type        = bool
  default     = false
}

variable "pod_subnet_cidr" {
  description = "CIDR for pod IPs. null = IBM default (172.30.0.0/16)."
  type        = string
  default     = null
}

variable "service_subnet_cidr" {
  description = "CIDR for service IPs. null = IBM default (172.21.0.0/16)."
  type        = string
  default     = null
}
