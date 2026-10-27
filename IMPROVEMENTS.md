# Improvements & To-Do

Suggested enhancements to this repository, roughly in order of practical priority.
Check items off as they are completed.

---

## 🔴 High priority — safety & reliability

- [ ] **Remote Terraform state (COS backend)**
  Move `terraform.tfstate` off local disk into an IBM Cloud Object Storage bucket.
  If a local state file is lost, all infrastructure becomes unmanageable ("orphaned") in Terraform.
  The existing COS instance created by this config can host the backend bucket at no extra cost.
  See: https://cloud.ibm.com/docs/ibm-cloud-provider-for-terraform?topic=ibm-cloud-provider-for-terraform-setup_cli#install_provider

- [ ] **IBM Cloud budget alert**
  Add a spending notification on the demo resource group so a forgotten running cluster
  triggers an email before it runs up a large bill.
  Threshold suggestion: $50 on the demo resource group.
  Configurable via the IBM Cloud console: **Manage → Billing and usage → Spending notifications**.

---

## 🟡 Medium priority — production readiness

- [ ] **KMS / Key Protect integration**
  Encrypt ROKS etcd, worker boot volumes, and the COS bucket at rest using a
  customer-managed root key. Required for FSCloud / financial services compliance.
  The `base-ocp-vpc` module already has a `kms_config` input ready to wire up —
  add `terraform-ibm-modules/kms/ibm` as a new module and connect it.

- [ ] **Secrets Manager integration**
  Wire `enable_secrets_manager_integration = true` on the OpenShift module so that
  Ingress TLS certificates are managed centrally and rotated automatically.
  Without this, Ingress certs are self-managed and expire without warning.
  Requires adding `terraform-ibm-modules/secrets-manager/ibm` to the composition.

- [ ] **`CONTRIBUTING.md`**
  Add contribution guidelines covering branch naming, PR process, and the
  "never commit tfvars" rule. Especially important if this repo is shared with
  customers or a broader team.

- [ ] **`CODEOWNERS`**
  Add a `.github/CODEOWNERS` file so pull requests automatically request review
  from the right people. Prevents unreviewed changes to infrastructure configs.

---

## 🟢 Lower priority — developer experience & demos

- [ ] **Sample application (`demo-app/`)**
  Add a minimal Hello World deployment, Service, and Route so customers have
  something to actually show after `demo-up.sh` completes — a live URL in a browser
  is far more compelling than `oc get nodes` alone.
  Suggested stack: a single-container Nginx or Node.js app with an OpenShift Route.

- [ ] **GitHub Actions CI pipeline**
  Add `.github/workflows/terraform-validate.yml` to run `terraform validate` and
  `terraform plan` on every pull request. Catches broken configs before they merge.
  Both the production config (`./`) and the demo config (`demo/`) should be checked.

- [ ] **Horizontal Pod Autoscaler + Cluster Autoscaler demo script**
  If `cluster-autoscaler` addon is enabled, add a script that generates load,
  triggers HPA pod scaling, and then shows the cluster autoscaler adding a node.
  This is a high-impact live demo moment — nodes visibly joining the cluster.

- [ ] **`CHANGELOG.md`**
  Track module version bumps and config changes over time. Useful when a customer
  asks "what changed since the last demo?"

- [ ] **Makefile convenience targets**
  Wrap common commands (`make demo-up`, `make demo-down`, `make validate`) so
  customers and contributors don't need to remember script paths or Terraform flags.
