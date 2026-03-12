output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_nodegroup_name" {
  value = module.eks.nodegroup_name
}

output "app_image_uri" {
  value = module.app.image_uri
}

output "app_namespace" {
  value = module.app.namespace
}

output "app_deployment_name" {
  value = module.app.deployment_name
}

output "app_service_name" {
  value = module.app.service_name
}

output "app_service_lb_hostname" {
  value = module.app.service_lb_hostname
}

output "app_hpa_name" {
  value = module.app.hpa_name
}

output "prod_namespace" {
  value = module.security.prod_namespace
}

output "dev_readonly_service_account" {
  value = module.security.dev_readonly_service_account
}

output "prod_operator_service_account" {
  value = module.security.prod_operator_service_account
}

output "overprivilege_simulation_enabled" {
  value = module.security.overprivilege_simulation_enabled
}
