terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Kubernetes provider for Cluster 1
provider "kubernetes" {
  alias = "cluster1"

  host                   = "https://${google_container_cluster.cluster1.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.cluster1.master_auth[0].cluster_ca_certificate)
}

# Kubernetes provider for Cluster 2
provider "kubernetes" {
  alias = "cluster2"

  host                   = "https://${google_container_cluster.cluster2.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.cluster2.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}