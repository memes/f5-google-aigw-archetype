variable "project_id" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id value must be a valid Google Cloud project identifier"
  }
  description = <<-EOD
  The Google Cloud project identifier that will contain the resources.
  EOD
}

variable "name" {
  type     = string
  nullable = false
  validation {
    # The generated service account names has a limit of 30 characters, including
    # the '-bot' suffix. Validate that var.name is 1 <= length(var.name) <=26.
    condition     = can(regex("^[a-z][a-z0-9-]{0,24}[a-z0-9]$", var.name))
    error_message = "The name variable must be RFC1035 compliant and between 1 and 26 characters in length."
  }
  description = <<-EOD
  The common name to use for resources.
  EOD
}

variable "region" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z]{2,}-[a-z]{2,}[0-9]$", var.region))
    error_message = "Region must be a valid Google Cloud region name."
  }
  default     = "us-west1"
  description = <<-EOD
  The Compute Engine region in which to create resources. Default is us-west1.
  EOD
}

variable "labels" {
  type     = map(string)
  nullable = true
  validation {
    # GCP resource labels must be lowercase alphanumeric, underscore or hyphen,
    # and the key must be <= 63 characters in length
    condition     = length(compact([for k, v in var.labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v)) ? "x" : ""])) == length(keys(var.labels))
    error_message = "Each label key:value pair must match GCP requirements."
  }
  default     = {}
  description = <<-EOD
  An optional set of key:value string pairs that will be added to GCP resources
  that accept labels.
  EOD
}


variable "repository" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z]{2,}(?:-[a-z]+[1-9])?-docker.pkg.dev/[^/]+/[^/]+", var.repository))
    error_message = "Repository must be a valid Artifact Registry repository."
  }
  description = <<-EOD
  The private Artifact Registry that will be used for deployments.
  EOD
}

variable "cloud_deploy_service_account" {
  type = string
  validation {
    condition     = can(regex("(?:[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}\\.iam|[1-9][0-9]+-compute@developer)\\.gserviceaccount\\.com$", var.cloud_deploy_service_account))
    error_message = "The cloud_deploy_service_account variable must be a valid GCP service account email address."
  }
  description = <<-EOD
  Optional Cloud Deploy execution service account that will deploy resources to GKE.
  EOD
}
