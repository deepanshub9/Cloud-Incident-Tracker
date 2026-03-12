output "tf_state_bucket" {
  value = aws_s3_bucket.tf_state.bucket
}

output "tf_lock_table" {
  value = aws_dynamodb_table.tf_locks.name
}

output "backend_init_command" {
  value = <<EOT
terraform -chdir=infra init \\
  -backend-config="bucket=${aws_s3_bucket.tf_state.bucket}" \\
  -backend-config="key=env/dev/terraform.tfstate" \\
  -backend-config="region=${var.aws_region}" \\
  -backend-config="dynamodb_table=${aws_dynamodb_table.tf_locks.name}" \\
  -backend-config="encrypt=true"
EOT
}
