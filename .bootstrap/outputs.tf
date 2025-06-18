output "iac_sa" {
  value = module.bootstrap.iac_sa
}

output "repo_url" {
  value = module.bootstrap.html_url
}

output "ar" {
  value = module.bootstrap.repo_identifiers["oci"]
}

output "deploy_sa" {
  value = module.bootstrap.deploy_sa
}
