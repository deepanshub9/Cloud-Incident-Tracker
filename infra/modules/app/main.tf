locals {
  image_uri = "${var.repository_url}:${var.image_tag}"

  deployment_values = {
    name      = var.app_name
    namespace = var.namespace
    image     = local.image_uri
    replicas  = var.desired_replicas
    port      = 8080
  }
}
