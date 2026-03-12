variable "app_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "repository_url" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "desired_replicas" {
  type = number
}

variable "container_port" {
  type = number
}

variable "cpu_request" {
  type = string
}

variable "cpu_limit" {
  type = string
}

variable "memory_request" {
  type = string
}

variable "memory_limit" {
  type = string
}

variable "hpa_min_replicas" {
  type = number
}

variable "hpa_max_replicas" {
  type = number
}

variable "hpa_cpu_target" {
  type = number
}
