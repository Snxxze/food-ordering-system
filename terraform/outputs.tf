output "namespace" {
  description = "The Kubernetes namespace created for the food ordering system"
  value       = kubernetes_namespace_v1.food_system.metadata[0].name
}

output "config_map_name" {
  description = "Name of the application ConfigMap"
  value       = kubernetes_config_map_v1.app_config.metadata[0].name
}
