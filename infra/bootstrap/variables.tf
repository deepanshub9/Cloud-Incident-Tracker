variable "project_name" {
  type    = string
  default = "secure-mini-cloud"
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "tf_state_bucket_name" {
  description = "Optional explicit bucket name for TF state"
  type        = string
  default     = ""
}

variable "force_destroy_state_bucket" {
  description = "Allow destroying non-empty state bucket (use only in lab)"
  type        = bool
  default     = false
}
