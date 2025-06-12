#

terraform {
  required_version = ">= 1.5"
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.4"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 6.12"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.12"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
  }
  # Change this to match the target GCS bucket that is managing Tofu/Terraform state
  backend "gcs" {
    bucket = "emes-stuff"
    prefix = "bootstrap/f5-google-aigw-archetype"
  }
}

# This assumes the provider is configured via environment variables GITHUB_TOKEN and GITHUB_OWNER; change as necessary.
# See https://registry.terraform.io/providers/integrations/github/latest/docs
provider "github" {}

# This assumes the provider is configured via ADC credentials and/or environment variables; change as necessary.
# See https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference
provider "google" {}

# This assumes the provider is configured via ADC credentials and/or environment variables; change as necessary.
# See https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference
provider "google-beta" {}


module "bootstrap" {
  # TODO @memes - pin once upstream is ready for Next 2025
  # tflint-ignore: terraform_module_pinned_source
  source     = "git::https://github.com/memes/terraform-google-f5-demo-bootstrap?ref=feat%2fcloud_deploy_infra_manager"
  project_id = var.project_id
  name       = var.name
  labels     = var.labels
  # spell-checker: disable
  bootstrap_apis = [
    "compute.googleapis.com",
    "config.googleapis.com",
    "container.googleapis.com",
    "dlp.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "modelarmor.googleapis.com",
  ]
  iac_roles = [
    "roles/compute.instanceAdmin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/config.agent",
    "roles/dns.admin",
    "roles/logging.logWriter",
  ]
  # spell-checker: enable
  impersonators  = var.impersonators
  collaborators  = var.collaborators
  github_options = var.github_options
}

module "cloud_deploy" {
  # TODO @memes - pin once upstream is ready for Next 2025
  # tflint-ignore: terraform_module_pinned_source
  source         = "git::https://github.com/memes/terraform-google-f5-demo-bootstrap//modules/cloud-deploy?ref=feat%2fcloud_deploy_infra_manager"
  project_id     = var.project_id
  name           = var.name
  labels         = var.labels
  bootstrap_apis = []
}

resource "local_sensitive_file" "sops" {
  filename             = abspath(format("../%s/.sops.yaml", path.module))
  directory_permission = "0755"
  file_permission      = "0644"
  content              = <<-EOC
  creation_rules:
    - path_regex: secrets\.yaml$
      gcp_kms: '${module.bootstrap.sops_kms_id}'
  EOC

  depends_on = [
    module.bootstrap,
  ]
}
