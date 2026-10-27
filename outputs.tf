# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

output "resource_group_id" {
  description = "ID of the resource group that contains all platform resources."
  value       = module.resource_group.resource_group_id
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = module.resource_group.resource_group_name
}

# ---------------------------------------------------------------------------
# COS
# ---------------------------------------------------------------------------

output "cos_instance_id" {
  description = "Resource ID of the COS instance."
  value       = module.cos.cos_instance_id
}

output "cos_instance_guid" {
  description = "GUID of the COS instance (used by VPC flow logs and registry)."
  value       = module.cos.cos_instance_guid
}

output "cos_bucket_name" {
  description = "Name of the COS bucket used for the OpenShift internal registry."
  value       = module.cos.bucket_name
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_crn" {
  description = "CRN of the VPC."
  value       = module.vpc.vpc_crn
}

output "vpc_name" {
  description = "Name of the VPC."
  value       = module.vpc.vpc_name
}

output "subnet_ids" {
  description = "Flat list of all subnet IDs across all zones."
  value       = module.vpc.subnet_ids
}

output "subnet_detail_map" {
  description = "Map of subnet details (id, CIDR, zone) keyed by subnet name prefix."
  value       = module.vpc.subnet_detail_map
}

output "subnet_zone_list" {
  description = "List of objects with subnet ID and zone (used by worker-pool wiring)."
  value       = module.vpc.subnet_zone_list
}

output "public_gateways" {
  description = "Map of public gateways by zone."
  value       = module.vpc.public_gateways
}

output "vpc_flow_logs" {
  description = "VPC flow-log collector details (null when flow logs are disabled)."
  value       = module.vpc.vpc_flow_logs
}

# ---------------------------------------------------------------------------
# OpenShift Cluster
# ---------------------------------------------------------------------------

output "cluster_id" {
  description = "ID of the OpenShift cluster."
  value       = module.openshift.cluster_id
}

output "cluster_name" {
  description = "Name of the OpenShift cluster."
  value       = module.openshift.cluster_name
}

output "cluster_crn" {
  description = "CRN of the OpenShift cluster."
  value       = module.openshift.cluster_crn
}

output "ocp_version" {
  description = "OpenShift version that was provisioned."
  value       = module.openshift.ocp_version
}

output "master_url" {
  description = "URL of the Kubernetes API master."
  value       = module.openshift.master_url
}

output "public_service_endpoint_url" {
  description = "Public service endpoint URL (empty string when public endpoint is disabled)."
  value       = module.openshift.public_service_endpoint_url
}

output "private_service_endpoint_url" {
  description = "Private service endpoint URL."
  value       = module.openshift.private_service_endpoint_url
}

output "vpe_url" {
  description = "Virtual Private Endpoint URL for the cluster."
  value       = module.openshift.vpe_url
}

output "ingress_hostname" {
  description = "Ingress subdomain hostname assigned to the cluster."
  value       = module.openshift.ingress_hostname
}

output "workerpools" {
  description = "Worker pool details including machine type and zone distribution."
  value       = module.openshift.workerpools
}
