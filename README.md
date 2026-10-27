# VPC + OpenShift Container Platform on IBM Cloud

A complete, production-ready Terraform configuration for deploying a multi-zone Red Hat OpenShift (ROKS) cluster on IBM Cloud VPC, including networking, subnets, object storage, and load-balancer-ready infrastructure.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  IBM Cloud Account                                                  │
│                                                                     │
│  ┌─────────────┐   ┌──────────────────────────────────────────┐    │
│  │ Resource    │   │ Cloud Object Storage                     │    │
│  │ Group       │   │  • Instance: ocp-platform-cos            │    │
│  └──────┬──────┘   │  • Bucket:   ocp-platform-registry       │    │
│         │          │    (image registry + VPC flow logs)      │    │
│         │          └──────────────────┬───────────────────────┘    │
│         │                             │                            │
│         │   ┌─────────────────────────▼──────────────────────┐    │
│         │   │  Multi-Zone VPC  (e.g. us-south)               │    │
│         │   │                                                 │    │
│         │   │  Zone 1            Zone 2            Zone 3    │    │
│         │   │  ┌────────────┐   ┌────────────┐   ┌────────┐  │    │
│         │   │  │Worker /24  │   │Worker /24  │   │Worker  │  │    │
│         │   │  │+ PGW       │   │+ PGW       │   │+ PGW   │  │    │
│         │   │  ├────────────┤   ├────────────┤   ├────────┤  │    │
│         │   │  │LB     /24  │   │LB     /24  │   │LB /24  │  │    │
│         │   │  └────────────┘   └────────────┘   └────────┘  │    │
│         │   │                                                 │    │
│         │   │  VPC ACL (IBM Cloud + VPC connectivity rules)   │    │
│         │   └─────────────────────────┬───────────────────────┘    │
│         │                             │                            │
│         │   ┌─────────────────────────▼──────────────────────┐    │
│         └──►│  OpenShift / ROKS Cluster                      │    │
│             │                                                 │    │
│             │  Default Worker Pool: bx2.4x16                  │    │
│             │  2 workers × 3 zones = 6 nodes (RHEL 8)         │    │
│             │                                                 │    │
│             │  ┌──────────────────────────────────────────┐   │    │
│             │  │ IBM-managed LBs  (auto-created per       │   │    │
│             │  │ Service/Ingress/Route on lb-zone subnets) │   │    │
│             │  └──────────────────────────────────────────┘   │    │
│             │                                                 │    │
│             │  VPE Gateways: master · registry · API          │    │
│             └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Modules used

| Module | Version | Role |
|---|---|---|
| [`terraform-ibm-modules/resource-group/ibm`](https://registry.terraform.io/modules/terraform-ibm-modules/resource-group/ibm) | 1.6.1 | Looks up or creates the resource group |
| [`terraform-ibm-modules/cos/ibm`](https://registry.terraform.io/modules/terraform-ibm-modules/cos/ibm) | 11.1.5 | COS instance + bucket for image registry and flow logs |
| [`terraform-ibm-modules/landing-zone-vpc/ibm`](https://registry.terraform.io/modules/terraform-ibm-modules/landing-zone-vpc/ibm) | 10.1.5 | Multi-zone VPC, subnets, public gateways, ACLs, flow-log collector |
| [`terraform-ibm-modules/base-ocp-vpc/ibm`](https://registry.terraform.io/modules/terraform-ibm-modules/base-ocp-vpc/ibm) | 4.1.0 | ROKS cluster with worker pools, VPE gateways, add-on support |

DA reference: [`terraform-ibm-modules/base-ocp-vpc/ibm — solutions/fully-configurable`](https://github.com/terraform-ibm-modules/terraform-ibm-base-ocp-vpc/tree/main/solutions/fully-configurable)

---

## Deployment order

Resources are created in strict dependency order:

```
resource_group  →  cos  →  vpc  →  openshift
```

| Step | Module | Key inputs wired from |
|---|---|---|
| 1 | `resource_group` | — |
| 2 | `cos` | `resource_group_id` |
| 3 | `vpc` | `resource_group_id`, `cos_instance_guid`, `cos_bucket_name` |
| 4 | `openshift` | `resource_group_id`, `vpc_id`, `subnet_detail_map`, `cos_instance_id` |

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Terraform ≥ 1.3.0 | `terraform version` |
| IBM Cloud API key | Must have Editor on VPC, ROKS, COS, and Resource Groups |
| IBM Cloud CLI (optional) | Useful for `ibmcloud ks cluster config` after deploy |

---

## Quick start

```bash
# 1. Clone / copy this directory
cd vpc-openshift-platform

# 2. Create your tfvars (never commit this file)
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars          # set ibmcloud_api_key at minimum

# 3. Initialise providers and modules
terraform init

# 4. Review the plan
terraform plan

# 5. Deploy  (~30–45 min for cluster provisioning)
terraform apply
```

After `apply` completes, retrieve the kubeconfig:

```bash
ibmcloud ks cluster config --cluster $(terraform output -raw cluster_id)
kubectl get nodes
```

---

## Files

```
vpc-openshift-platform/
├── versions.tf              # Provider version constraints
├── variables.tf             # All input variables with defaults
├── main.tf                  # Module composition
├── outputs.tf               # 25+ outputs (IDs, URLs, hostnames)
└── terraform.tfvars.example # Copy → terraform.tfvars and fill in values
```

---

## Configuration reference

### Required variable

| Variable | Type | Description |
|---|---|---|
| `ibmcloud_api_key` | `string` | IBM Cloud API key (**sensitive**) |

### Key optional variables

| Variable | Default | Description |
|---|---|---|
| `region` | `us-south` | IBM Cloud region |
| `prefix` | `ocp-platform` | Prepended to every resource name |
| `resource_group_name` | `null` | Existing RG name; `null` creates `<prefix>-rg` |
| `vpc_name` | `vpc` | Base name for the VPC |
| `cluster_name` | `roks-cluster` | Base name for the OpenShift cluster |
| `ocp_version` | `null` | OpenShift version (e.g. `4.15`); `null` = IBM default |
| `disable_public_endpoint` | `false` | `true` = private-only cluster |
| `enable_vpc_flow_logs` | `true` | Capture flow logs into the COS bucket |
| `worker_pools` | see below | List of worker-pool definitions |
| `addons` | `{}` | Cluster add-ons to enable (see Add-ons section) |

### Default worker pool

```hcl
worker_pools = [
  {
    pool_name        = "default"
    machine_type     = "bx2.4x16"   # 4 vCPU / 16 GB RAM
    workers_per_zone = 2             # × 3 zones = 6 nodes total
    operating_system = "REDHAT_8_64"
    subnet_prefix    = "worker"      # targets subnets named "worker-zone-*"
  }
]
```

To add a GPU or high-memory pool, append another object to the list:

```hcl
worker_pools = [
  { pool_name = "default",  machine_type = "bx2.4x16",   workers_per_zone = 2, operating_system = "REDHAT_8_64", subnet_prefix = "worker" },
  { pool_name = "compute",  machine_type = "cx2.8x16",   workers_per_zone = 1, operating_system = "REDHAT_8_64", subnet_prefix = "worker" },
]
```

### Default subnet layout (per zone)

| Subnet name | CIDR | Public gateway | Purpose |
|---|---|---|---|
| `worker-zone-1` | `10.10.10.0/24` | ✅ | Worker node egress |
| `lb-zone-1` | `10.10.20.0/24` | ❌ | IBM-managed LBs (private) |
| `worker-zone-2` | `10.20.10.0/24` | ✅ | Worker node egress |
| `lb-zone-2` | `10.20.20.0/24` | ❌ | IBM-managed LBs (private) |
| `worker-zone-3` | `10.30.10.0/24` | ✅ | Worker node egress |
| `lb-zone-3` | `10.30.20.0/24` | ❌ | IBM-managed LBs (private) |

Override via the `subnets` variable if these CIDRs conflict with existing infrastructure.

---

## Load balancers

VPC Application Load Balancers are **provisioned automatically by ROKS** when you create:

- An OpenShift `Service` of type `LoadBalancer`
- An OpenShift `Route` or `Ingress` resource

The dedicated `lb-zone-*` subnets (no public gateway) keep LB data-plane traffic isolated from worker node egress. Use the `additional_lb_security_group_ids` and `number_of_lbs` inputs on the OpenShift module to attach custom security groups to those LBs after provisioning.

---

## Add-ons

Enable cluster add-ons by setting the `addons` variable:

```hcl
addons = {
  cluster-autoscaler   = {}   # Horizontal node autoscaling
  vpc-block-csi-driver = {}   # VPC block storage (ReadWriteOnce)
  vpc-file-csi-driver  = {}   # VPC file storage (ReadWriteMany)
}
```

Full list of supported add-ons and versions: https://cloud.ibm.com/docs/containers?topic=containers-supported-cluster-addon-versions

---

## Key outputs

| Output | Description |
|---|---|
| `cluster_id` | ROKS cluster ID |
| `cluster_name` | Full cluster name (with prefix) |
| `ingress_hostname` | Assigned Ingress subdomain |
| `public_service_endpoint_url` | Public API endpoint (empty if private-only) |
| `private_service_endpoint_url` | Private API endpoint |
| `vpc_id` | VPC resource ID |
| `subnet_ids` | All subnet IDs across zones |
| `cos_bucket_name` | COS bucket backing the image registry |

---

## Teardown

```bash
terraform destroy
```

> **Note:** By default, destroying the cluster does **not** delete attached block-storage PVCs. Set `force_delete_storage = true` on the OpenShift module if you want storage deleted alongside the cluster.
