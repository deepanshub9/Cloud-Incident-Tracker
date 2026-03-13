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
  node_capacity_type  = var.node_capacity_type
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "app" {
  source = "./modules/app"

  app_name         = var.app_name
  namespace        = var.environment
  repository_url   = module.ecr.repository_url
  image_tag        = var.app_image_tag
  desired_replicas = var.app_desired_replicas
  container_port   = var.app_container_port
  cpu_request      = var.app_cpu_request
  cpu_limit        = var.app_cpu_limit
  memory_request   = var.app_memory_request
  memory_limit     = var.app_memory_limit
  hpa_min_replicas = var.app_hpa_min_replicas
  hpa_max_replicas = var.app_hpa_max_replicas
  hpa_cpu_target   = var.app_hpa_cpu_target

  depends_on = [module.eks]
}

module "security" {
  source = "./modules/security"

  project_name               = var.project_name
  dev_namespace              = var.environment
  prod_namespace             = var.prod_namespace
  app_name                   = var.app_name
  app_port                   = var.app_container_port
  dev_cpu_requests_quota     = var.security_dev_cpu_requests_quota
  dev_cpu_limits_quota       = var.security_dev_cpu_limits_quota
  dev_memory_requests_quota  = var.security_dev_memory_requests_quota
  dev_memory_limits_quota    = var.security_dev_memory_limits_quota
  dev_pod_quota              = var.security_dev_pod_quota
  prod_cpu_requests_quota    = var.security_prod_cpu_requests_quota
  prod_cpu_limits_quota      = var.security_prod_cpu_limits_quota
  prod_memory_requests_quota = var.security_prod_memory_requests_quota
  prod_memory_limits_quota   = var.security_prod_memory_limits_quota
  prod_pod_quota             = var.security_prod_pod_quota
  default_cpu_request        = var.security_default_cpu_request
  default_cpu_limit          = var.security_default_cpu_limit
  default_memory_request     = var.security_default_memory_request
  default_memory_limit       = var.security_default_memory_limit
  simulate_overprivilege     = var.simulate_overprivilege

  depends_on = [module.app]
}

module "observability" {
  count  = var.enable_observability ? 1 : 0
  source = "./modules/observability"

  cluster_name           = module.eks.cluster_name
  aws_region             = var.aws_region
  monitoring_namespace   = var.monitoring_namespace
  app_namespace          = var.environment
  app_name               = var.app_name
  app_service_port_name  = "http"
  prometheus_retention   = var.prometheus_retention
  grafana_service_type   = var.grafana_service_type
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.security]
}
