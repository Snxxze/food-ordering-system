variable "namespace" {
  description = "Kubernetes namespace for the food ordering system"
  type        = string
  default     = "food-system"
}

variable "environment" {
  description = "Deployment environment (dev/staging/production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production"
  }
}

variable "app_name" {
  description = "Application name used for labeling resources"
  type        = string
  default     = "food-ordering"
}

variable "kube_config_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}
