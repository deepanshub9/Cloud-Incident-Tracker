data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.tf_state_bucket_name != "" ? var.tf_state_bucket_name : "${var.project_name}-${data.aws_caller_identity.current.account_id}-tf-state"
  table_name  = "${var.project_name}-tf-locks"
}

resource "aws_s3_bucket" "tf_state" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy_state_bucket
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
