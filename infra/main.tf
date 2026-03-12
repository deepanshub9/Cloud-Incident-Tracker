module "network" {
  source = "./modules/network"

  name_prefix         = "${var.project_name}-${var.environment}"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix = "${var.project_name}-${var.environment}"
  repository  = "${var.project_name}-app"
}

module "eks" {
  source = "./modules/eks"

  name_prefix         = "${var.project_name}-${var.environment}"
  cluster_version     = var.eks_version
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "app" {
  source = "./modules/app"

  app_name         = "incident-tracker"
  namespace        = var.environment
  repository_url   = module.ecr.repository_url
  image_tag        = var.app_image_tag
  desired_replicas = 1
}
