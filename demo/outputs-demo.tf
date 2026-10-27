# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------

output "resource_group_id" {
  description = "ID of the resource group."
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

output "cos_bucket_name" {
  description = "COS bucket backing the OpenShift internal registry."
  value       = module.cos.bucket_name
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "Name of the VPC."
  value       = module.vpc.vpc_name
}

output "subnet_ids" {
  description = "All subnet IDs (single zone in this demo config)."
  value       = module.vpc.subnet_ids
}

# ---------------------------------------------------------------------------
# OpenShift Cluster
# ---------------------------------------------------------------------------

output "cluster_id" {
  description = "ID of the OpenShift cluster."
  value       = module.openshift.cluster_id
}

output "cluster_name" {
  description = "Full name of the OpenShift cluster (with prefix)."
  value       = module.openshift.cluster_name
}

output "cluster_crn" {
  description = "CRN of the OpenShift cluster."
  value       = module.openshift.cluster_crn
}

output "ocp_version" {
  description = "OpenShift version provisioned."
  value       = module.openshift.ocp_version
}

output "ingress_hostname" {
  description = "Ingress subdomain hostname — use this for demo app routes."
  value       = module.openshift.ingress_hostname
}

output "public_service_endpoint_url" {
  description = "Public API endpoint URL."
  value       = module.openshift.public_service_endpoint_url
}

output "private_service_endpoint_url" {
  description = "Private API endpoint URL."
  value       = module.openshift.private_service_endpoint_url
}

output "master_url" {
  description = "Kubernetes master URL."
  value       = module.openshift.master_url
}

# ---------------------------------------------------------------------------
# Handy cost reminder
# ---------------------------------------------------------------------------

output "cost_reminder" {
  description = "Estimated running cost for this demo configuration."
  value       = "~$0.21/hr (~$150/mo). Run 'terraform destroy' when the demo is done to stop all charges."
}
