variable "project_name" {
  description = "Project name prefix used for resources"
  type        = string
  default     = "secure-mini-cloud"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnets for EKS"
  type        = list(string)
  default     = ["10.50.1.0/24", "10.50.2.0/24"]
}

variable "eks_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "EKS nodegroup instance types"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_capacity_type" {
  description = "EKS nodegroup capacity type (SPOT or ON_DEMAND)"
  type        = string
  default     = "SPOT"
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 2
}

variable "app_image_tag" {
  description = "Container image tag for app module metadata"
  type        = string
  default     = "v2"
}

variable "app_name" {
  description = "Application name used for Kubernetes resources"
  type        = string
  default     = "incident-tracker"
}

variable "app_desired_replicas" {
  description = "Desired replica count for app deployment"
  type        = number
  default     = 1
}

variable "app_container_port" {
  description = "Container and service port for app"
  type        = number
  default     = 8080
}

variable "app_cpu_request" {
  description = "CPU request for app container"
  type        = string
  default     = "100m"
}

variable "app_cpu_limit" {
  description = "CPU limit for app container"
  type        = string
  default     = "500m"
}

variable "app_memory_request" {
  description = "Memory request for app container"
  type        = string
  default     = "128Mi"
}

variable "app_memory_limit" {
  description = "Memory limit for app container"
  type        = string
  default     = "512Mi"
}

variable "app_hpa_min_replicas" {
  description = "Minimum replicas for app HPA"
  type        = number
  default     = 1
}

variable "app_hpa_max_replicas" {
  description = "Maximum replicas for app HPA"
  type        = number
  default     = 4
}

variable "app_hpa_cpu_target" {
  description = "Target average CPU utilization percentage for HPA"
  type        = number
  default     = 60
}

variable "prod_namespace" {
  description = "Production namespace for multi-tenancy simulation"
  type        = string
  default     = "prod"
}

variable "security_dev_cpu_requests_quota" {
  description = "Dev namespace quota for total CPU requests"
  type        = string
  default     = "1000m"
}

variable "security_dev_cpu_limits_quota" {
  description = "Dev namespace quota for total CPU limits"
  type        = string
  default     = "2000m"
}

variable "security_dev_memory_requests_quota" {
  description = "Dev namespace quota for total memory requests"
  type        = string
  default     = "1Gi"
}

variable "security_dev_memory_limits_quota" {
  description = "Dev namespace quota for total memory limits"
  type        = string
  default     = "2Gi"
}

variable "security_dev_pod_quota" {
  description = "Dev namespace pod count quota"
  type        = string
  default     = "10"
}

variable "security_prod_cpu_requests_quota" {
  description = "Prod namespace quota for total CPU requests"
  type        = string
  default     = "2000m"
}

variable "security_prod_cpu_limits_quota" {
  description = "Prod namespace quota for total CPU limits"
  type        = string
  default     = "4000m"
}

variable "security_prod_memory_requests_quota" {
  description = "Prod namespace quota for total memory requests"
  type        = string
  default     = "2Gi"
}

variable "security_prod_memory_limits_quota" {
  description = "Prod namespace quota for total memory limits"
  type        = string
  default     = "4Gi"
}

variable "security_prod_pod_quota" {
  description = "Prod namespace pod count quota"
  type        = string
  default     = "20"
}

variable "security_default_cpu_request" {
  description = "Default CPU request in namespaces with LimitRange"
  type        = string
  default     = "100m"
}

variable "security_default_cpu_limit" {
  description = "Default CPU limit in namespaces with LimitRange"
  type        = string
  default     = "500m"
}

variable "security_default_memory_request" {
  description = "Default memory request in namespaces with LimitRange"
  type        = string
  default     = "128Mi"
}

variable "security_default_memory_limit" {
  description = "Default memory limit in namespaces with LimitRange"
  type        = string
  default     = "512Mi"
}

variable "simulate_overprivilege" {
  description = "Set true to intentionally bind prod operator to cluster-admin (for simulation)"
  type        = bool
  default     = false
}
