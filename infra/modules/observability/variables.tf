variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "monitoring_namespace" {
  type = string
}

variable "app_namespace" {
  type = string
}

variable "app_name" {
  type = string
}

variable "app_service_port_name" {
  type    = string
  default = "http"
}

variable "prometheus_retention" {
  type = string
}

variable "grafana_service_type" {
  type = string
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}
