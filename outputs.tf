output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE cluster name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE cluster endpoint"
  sensitive   = true
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  description = "GKE cluster CA certificate"
  sensitive   = true
}

output "filestore_instance_name" {
  value       = google_filestore_instance.instance.name
  description = "Filestore instance name"
}

output "filestore_ip_address" {
  value       = google_filestore_instance.instance.networks[0].ip_addresses[0]
  description = "Filestore instance IP address"
}

output "filestore_share_name" {
  value       = google_filestore_instance.instance.file_shares[0].name
  description = "Filestore share name"
}

output "vpc_network_name" {
  value       = google_compute_network.vpc.name
  description = "VPC network name"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "Subnet name"
}

output "kubectl_config_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  description = "Command to configure kubectl"
}

output "storage_class_name" {
  value       = kubernetes_storage_class.filestore.metadata[0].name
  description = "Kubernetes StorageClass name for Filestore"
}