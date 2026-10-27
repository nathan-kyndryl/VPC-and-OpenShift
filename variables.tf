# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key used to authenticate with IBM Cloud."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region to deploy all resources into (e.g. us-south, eu-de)."
  type        = string
  default     = "us-south"
}

variable "prefix" {
  description = "Prefix prepended to every resource name for easy identification."
  type        = string
  default     = "ocp-platform"
}

variable "resource_tags" {
  description = "List of user tags applied to every resource (format: key:value)."
  type        = list(string)
  default     = []
}

variable "access_tags" {
  description = "List of IBM Cloud access-management tags applied to every resource."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of an existing IBM Cloud resource group. If null a new group is created."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# VPC / Networking
# ---------------------------------------------------------------------------

variable "vpc_name" {
  description = "Base name for the VPC (prefix is prepended automatically)."
  type        = string
  default     = "vpc"
}

variable "network_cidrs" {
  description = "Supernet CIDRs used in VPC ACL rules for cluster provisioning."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "subnets" {
  description = <<-EOT
    Subnet configuration per availability zone.
    Each zone receives one worker subnet and one load-balancer subnet.
    Public gateways are enabled on worker subnets so nodes can reach the internet.
  EOT
  type = object({
    zone-1 = list(object({
      name           = string
      cidr           = string
      public_gateway = optional(bool, false)
      acl_name       = string
      no_addr_prefix = optional(bool, false)
    }))
    zone-2 = optional(list(object({
      name           = string
      cidr           = string
      public_gateway = optional(bool, false)
      acl_name       = string
      no_addr_prefix = optional(bool, false)
    })))
    zone-3 = optional(list(object({
      name           = string
      cidr           = string
      public_gateway = optional(bool, false)
      acl_name       = string
      no_addr_prefix = optional(bool, false)
    })))
  })
  default = {
    zone-1 = [
      { name = "worker-zone-1", cidr = "10.10.10.0/24", public_gateway = true, acl_name = "vpc-acl" },
      { name = "lb-zone-1",     cidr = "10.10.20.0/24", public_gateway = false, acl_name = "vpc-acl" }
    ]
    zone-2 = [
      { name = "worker-zone-2", cidr = "10.20.10.0/24", public_gateway = true, acl_name = "vpc-acl" },
      { name = "lb-zone-2",     cidr = "10.20.20.0/24", public_gateway = false, acl_name = "vpc-acl" }
    ]
    zone-3 = [
      { name = "worker-zone-3", cidr = "10.30.10.0/24", public_gateway = true, acl_name = "vpc-acl" },
      { name = "lb-zone-3",     cidr = "10.30.20.0/24", public_gateway = false, acl_name = "vpc-acl" }
    ]
  }
}

variable "enable_vpc_flow_logs" {
  description = "Set to true to capture VPC flow logs into the COS bucket."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# OpenShift Cluster
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the OpenShift (ROKS) cluster."
  type        = string
  default     = "roks-cluster"
}

variable "ocp_version" {
  description = "OpenShift version to provision (format: 4.x). null = IBM Cloud default."
  type        = string
  default     = null
}

variable "worker_pools" {
  description = "Worker-pool definitions. At minimum one pool is required."
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
      machine_type     = "bx2.4x16"
      workers_per_zone = 2
      operating_system = "REDHAT_8_64"
      subnet_prefix    = "worker"
    }
  ]
}

variable "disable_public_endpoint" {
  description = "Set to true to create a private-only cluster (no public service endpoint)."
  type        = bool
  default     = false
}

variable "pod_subnet_cidr" {
  description = "CIDR (/23 or larger) for pod IP allocation. null = IBM default 172.30.0.0/16."
  type        = string
  default     = null
}

variable "service_subnet_cidr" {
  description = "CIDR (/24 or larger) for service IP allocation. null = IBM default 172.21.0.0/16."
  type        = string
  default     = null
}

variable "addons" {
  description = "Map of OCP add-on versions to install on the cluster."
  type = object({
    cluster-autoscaler = optional(object({ version = optional(string) }))
    vpc-block-csi-driver = optional(object({ version = optional(string) }))
    vpc-file-csi-driver  = optional(object({ version = optional(string) }))
  })
  default = {}
}
