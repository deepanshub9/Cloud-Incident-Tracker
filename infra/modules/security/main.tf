resource "kubernetes_namespace" "prod" {
  metadata {
    name = var.prod_namespace

    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_resource_quota_v1" "dev" {
  metadata {
    name      = "compute-quota"
    namespace = var.dev_namespace
  }

  spec {
    hard = {
      "requests.cpu"    = var.dev_cpu_requests_quota
      "limits.cpu"      = var.dev_cpu_limits_quota
      "requests.memory" = var.dev_memory_requests_quota
      "limits.memory"   = var.dev_memory_limits_quota
      "pods"            = var.dev_pod_quota
    }
  }
}

resource "kubernetes_resource_quota_v1" "prod" {
  metadata {
    name      = "compute-quota"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.prod_cpu_requests_quota
      "limits.cpu"      = var.prod_cpu_limits_quota
      "requests.memory" = var.prod_memory_requests_quota
      "limits.memory"   = var.prod_memory_limits_quota
      "pods"            = var.prod_pod_quota
    }
  }
}

resource "kubernetes_limit_range_v1" "dev" {
  metadata {
    name      = "container-limits"
    namespace = var.dev_namespace
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = var.default_cpu_limit
        memory = var.default_memory_limit
      }

      default_request = {
        cpu    = var.default_cpu_request
        memory = var.default_memory_request
      }
    }
  }
}

resource "kubernetes_limit_range_v1" "prod" {
  metadata {
    name      = "container-limits"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = var.default_cpu_limit
        memory = var.default_memory_limit
      }

      default_request = {
        cpu    = var.default_cpu_request
        memory = var.default_memory_request
      }
    }
  }
}

resource "kubernetes_service_account_v1" "dev_reader" {
  metadata {
    name      = "dev-reader"
    namespace = var.dev_namespace
  }
}

resource "kubernetes_role_v1" "dev_readonly" {
  metadata {
    name      = "readonly"
    namespace = var.dev_namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "dev_readonly" {
  metadata {
    name      = "dev-readonly-binding"
    namespace = var.dev_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dev_readonly.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dev_reader.metadata[0].name
    namespace = var.dev_namespace
  }
}

resource "kubernetes_service_account_v1" "prod_operator" {
  metadata {
    name      = "prod-operator"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
}

resource "kubernetes_role_v1" "prod_operator" {
  metadata {
    name      = "operator"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "prod_operator" {
  metadata {
    name      = "prod-operator-binding"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.prod_operator.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.prod_operator.metadata[0].name
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "prod_cluster_admin_simulation" {
  count = var.simulate_overprivilege ? 1 : 0

  metadata {
    name = "${var.project_name}-prod-cluster-admin-sim"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.prod_operator.metadata[0].name
    namespace = kubernetes_namespace.prod.metadata[0].name
  }
}

resource "kubernetes_network_policy_v1" "dev_default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = var.dev_namespace
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "prod_default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}

resource "kubernetes_network_policy_v1" "dev_allow_ingress_app" {
  metadata {
    name      = "allow-incident-tracker-ingress"
    namespace = var.dev_namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = var.app_name
      }
    }

    ingress {
      from {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        port     = var.app_port
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "dev_allow_dns_egress" {
  metadata {
    name      = "allow-dns-egress"
    namespace = var.dev_namespace
  }

  spec {
    pod_selector {}

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }

        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }

      ports {
        port     = 53
        protocol = "UDP"
      }

      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }
}

resource "kubernetes_network_policy_v1" "prod_allow_dns_egress" {
  metadata {
    name      = "allow-dns-egress"
    namespace = kubernetes_namespace.prod.metadata[0].name
  }

  spec {
    pod_selector {}

    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }

        pod_selector {
          match_labels = {
            "k8s-app" = "kube-dns"
          }
        }
      }

      ports {
        port     = 53
        protocol = "UDP"
      }

      ports {
        port     = 53
        protocol = "TCP"
      }
    }

    policy_types = ["Egress"]
  }
}
