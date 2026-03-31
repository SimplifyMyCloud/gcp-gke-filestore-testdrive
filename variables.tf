variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources"
  type        = string
  default     = "us-west1"
}

# Cluster 1 Configuration
variable "cluster1_name" {
  description = "Name of the first GKE cluster"
  type        = string
  default     = "filestore-cluster-1"
}

variable "cluster1_zone" {
  description = "Zone for the first GKE cluster"
  type        = string
  default     = "us-west1-a"
}

variable "cluster1_subnet_cidr" {
  description = "CIDR range for the first cluster's subnet"
  type        = string
  default     = "10.0.0.0/24"
}

# Cluster 2 Configuration
variable "cluster2_name" {
  description = "Name of the second GKE cluster"
  type        = string
  default     = "filestore-cluster-2"
}

variable "cluster2_zone" {
  description = "Zone for the second GKE cluster"
  type        = string
  default     = "us-west1-b"
}

variable "cluster2_subnet_cidr" {
  description = "CIDR range for the second cluster's subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Shared Network Configuration
variable "pods_cidr_cluster1" {
  description = "CIDR range for GKE pods in cluster 1"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr_cluster1" {
  description = "CIDR range for GKE services in cluster 1"
  type        = string
  default     = "10.2.0.0/16"
}

variable "pods_cidr_cluster2" {
  description = "CIDR range for GKE pods in cluster 2"
  type        = string
  default     = "10.3.0.0/16"
}

variable "services_cidr_cluster2" {
  description = "CIDR range for GKE services in cluster 2"
  type        = string
  default     = "10.4.0.0/16"
}

# Node Pool Configuration
variable "node_count" {
  description = "Initial number of nodes per cluster"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 4
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "n2-standard-4"  # Larger for Enterprise testing
}

variable "preemptible_nodes" {
  description = "Use preemptible nodes to reduce costs"
  type        = bool
  default     = false  # Enterprise testing needs stability
}

# Enterprise Filestore Configuration
variable "filestore_name" {
  description = "Name of the Enterprise Filestore instance"
  type        = string
  default     = "enterprise-filestore-shared"
}

variable "filestore_tier" {
  description = "Filestore tier (ENTERPRISE for this test)"
  type        = string
  default     = "ENTERPRISE"
}

variable "filestore_capacity_gb" {
  description = "Filestore capacity in GB (min 1TB for Enterprise)"
  type        = number
  default     = 1024
}

variable "filestore_share_name" {
  description = "Name of the primary NFS share in Filestore"
  type        = string
  default     = "shared_data"
}

variable "filestore_share2_name" {
  description = "Name of the secondary NFS share (Enterprise supports multiple)"
  type        = string
  default     = "cluster_specific"
}