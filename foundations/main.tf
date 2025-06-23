terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.12"
    }
  }
}

data "google_project" "project" {
  project_id = var.project_id
}

data "google_compute_zones" "zones" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}


module "vpc" {
  source      = "memes/multi-region-private-network/google"
  version     = "4.0.0"
  project_id  = var.project_id
  name        = var.name
  description = "Application VPC for AI Gateway"
  regions = [
    var.region,
  ]
  cidrs = {
    primary_ipv4_cidr          = "172.16.0.0/12"
    primary_ipv4_subnet_size   = 16
    primary_ipv4_subnet_offset = 0
    primary_ipv4_subnet_step   = 1
    primary_ipv6_cidr          = null
    secondaries = {
      pods = {
        ipv4_cidr          = "10.0.0.0/8"
        ipv4_subnet_size   = 16
        ipv4_subnet_offset = 0
        ipv4_subnet_step   = 1
      }
      services = {
        ipv4_cidr          = "192.168.0.0/16"
        ipv4_subnet_size   = 24
        ipv4_subnet_offset = 0
        ipv4_subnet_step   = 1
      }
    }
  }
}

module "googleapis-dns" {
  source     = "memes/restricted-apis-dns/google"
  version    = "2.0.0"
  project_id = var.project_id
  name       = var.name
  network_self_links = [
    module.vpc.self_link,
  ]
}

module "bastion" {
  source                = "memes/private-bastion/google"
  version               = "4.0.0"
  project_id            = var.project_id
  name                  = format("%s-jmp", var.name)
  proxy_container_image = format("%s/memes/terraform-google-private-bastion/forward-proxy:4.0.0", var.repository)
  external_ip           = false
  zone                  = reverse(data.google_compute_zones.zones.names)[0]
  subnet                = [for k, v in module.vpc.subnets_by_region : v.self_link][0]
  bastion_targets = {
    cidrs = flatten(concat(
      [for k, v in module.vpc.subnets_by_name : v.primary_ipv4_cidr],
      [for k, v in module.vpc.subnets_by_region : [for x, y in v.secondary_ipv4_cidrs : y]]),
    )
    service_accounts = null
    priority         = 900
  }
}

module "sa" {
  source       = "git::https://github.com/memes/terraform-google-private-gke-cluster//modules/sa?ref=feat%2F75_add_missing_feature_support"
  project_id   = var.project_id
  name         = var.name
  description  = "AI Gateway archetype testing GKE node account"
  display_name = "AIGW GKE node account"
  repositories = [
    var.repository,
  ]
}

module "autopilot" {
  source          = "git::https://github.com/memes/terraform-google-private-gke-cluster//modules/autopilot?ref=feat%2F75_add_missing_feature_support"
  project_id      = var.project_id
  name            = var.name
  description     = "AI Gateway on GKE Autopilot"
  service_account = module.sa.email
  subnet = {
    self_link           = module.vpc.subnets_by_region[var.region].self_link
    pods_range_name     = "pods"
    services_range_name = "services"
    master_cidr         = "192.168.1.0/28"
  }
  master_authorized_networks = coalesce(try(module.bastion.ip_address, "unspecified"), "unspecified") == "unspecified" ? [] : [
    {
      display_name = "bastion host"
      cidr_block   = format("%s/32", module.bastion.ip_address)
    },
  ]
  labels = var.labels
}

resource "google_project_iam_member" "deploy_gke" {
  for_each = { for sa in compact([var.cloud_deploy_service_account]) : sa => true }
  project  = var.project_id
  role     = "roles/container.developer"
  member   = format("serviceAccount:%s", each.key)
}

resource "google_secret_manager_secret_iam_member" "nginx" {
  for_each  = coalesce(var.nginx_jwt_secret_id, "unspecified") == "unspecified" ? {} : { jwt = var.nginx_jwt_secret_id }
  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = format("principal://iam.googleapis.com/projects/%s/locations/global/workloadIdentityPools/%s.svc.id.goog/subject/ns/nginx-ingress/sa/nginx-ingress", data.google_project.project.number, var.project_id)
}
