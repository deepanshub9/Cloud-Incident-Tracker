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
