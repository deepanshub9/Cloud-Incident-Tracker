variable "project_name" {
  type = string
}

variable "dev_namespace" {
  type = string
}

variable "prod_namespace" {
  type = string
}

variable "app_name" {
  type = string
}

variable "app_port" {
  type = number
}

variable "dev_cpu_requests_quota" {
  type = string
}

variable "dev_cpu_limits_quota" {
  type = string
}

variable "dev_memory_requests_quota" {
  type = string
}

variable "dev_memory_limits_quota" {
  type = string
}

variable "dev_pod_quota" {
  type = string
}

variable "prod_cpu_requests_quota" {
  type = string
}

variable "prod_cpu_limits_quota" {
  type = string
}

variable "prod_memory_requests_quota" {
  type = string
}

variable "prod_memory_limits_quota" {
  type = string
}

variable "prod_pod_quota" {
  type = string
}

variable "default_cpu_request" {
  type = string
}

variable "default_cpu_limit" {
  type = string
}

variable "default_memory_request" {
  type = string
}

variable "default_memory_limit" {
  type = string
}

variable "simulate_overprivilege" {
  type = bool
}
