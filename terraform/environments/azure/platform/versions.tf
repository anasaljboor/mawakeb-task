terraform {
  required_version = "~> 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 5.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 3.3.0"
    }
  }
}
