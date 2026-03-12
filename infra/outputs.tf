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
