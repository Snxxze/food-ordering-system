provider "kubernetes" {
  # ปล่อยว่างไว้ Terraform จะดึงกุญแจจาก environment variable (KUBECONFIG) ของ Jenkins โดยอัตโนมัติ
}

resource "kubernetes_namespace_v1" "food_system" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of"    = var.app_name
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                   = var.environment
    }
  }
}

resource "kubernetes_config_map_v1" "app_config" {
  metadata {
    name      = "food-app-config"
    namespace = kubernetes_namespace_v1.food_system.metadata[0].name
    labels = {
      "app.kubernetes.io/part-of" = var.app_name
    }
  }

  data = {
    "APP_ENV"    = var.environment
    "APP_NAME"   = var.app_name
    "NAMESPACE"  = var.namespace
  }
}
