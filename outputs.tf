# Cluster 1 Outputs
output "cluster1_name" {
  value       = google_container_cluster.cluster1.name
  description = "Name of GKE cluster 1"
}

output "cluster1_endpoint" {
  value       = google_container_cluster.cluster1.endpoint
  description = "Endpoint for GKE cluster 1"
  sensitive   = true
}

output "cluster1_zone" {
  value       = google_container_cluster.cluster1.location
  description = "Zone of GKE cluster 1"
}

# Cluster 2 Outputs
output "cluster2_name" {
  value       = google_container_cluster.cluster2.name
  description = "Name of GKE cluster 2"
}

output "cluster2_endpoint" {
  value       = google_container_cluster.cluster2.endpoint
  description = "Endpoint for GKE cluster 2"
  sensitive   = true
}

output "cluster2_zone" {
  value       = google_container_cluster.cluster2.location
  description = "Zone of GKE cluster 2"
}

# Filestore Outputs
output "filestore_instance_name" {
  value       = google_filestore_instance.enterprise_shared.name
  description = "Enterprise Filestore instance name"
}

output "filestore_ip_address" {
  value       = google_filestore_instance.enterprise_shared.networks[0].ip_addresses[0]
  description = "Enterprise Filestore IP address"
}

output "filestore_share1_name" {
  value       = google_filestore_instance.enterprise_shared.file_shares[0].name
  description = "Primary Filestore share name"
}


output "filestore_tier" {
  value       = google_filestore_instance.enterprise_shared.tier
  description = "Filestore tier (ENTERPRISE)"
}

output "filestore_capacity_gb" {
  value       = google_filestore_instance.enterprise_shared.file_shares[0].capacity_gb
  description = "Primary share capacity in GB"
}

# Network Outputs
output "vpc_network_name" {
  value       = google_compute_network.shared_vpc.name
  description = "Shared VPC network name"
}

output "cluster1_subnet_name" {
  value       = google_compute_subnetwork.cluster1_subnet.name
  description = "Subnet name for cluster 1"
}

output "cluster2_subnet_name" {
  value       = google_compute_subnetwork.cluster2_subnet.name
  description = "Subnet name for cluster 2"
}

# kubectl Configuration Commands
output "kubectl_config_cluster1" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.cluster1.name} --zone ${var.cluster1_zone} --project ${var.project_id}"
  description = "Command to configure kubectl for cluster 1"
}

output "kubectl_config_cluster2" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.cluster2.name} --zone ${var.cluster2_zone} --project ${var.project_id}"
  description = "Command to configure kubectl for cluster 2"
}

# Test Commands
output "test_commands" {
  value = <<-EOT

    ============================================
    Multi-Cluster Enterprise Filestore Test Commands
    ============================================

    1. Configure kubectl for Cluster 1:
       ${format("gcloud container clusters get-credentials %s --zone %s --project %s",
         google_container_cluster.cluster1.name,
         var.cluster1_zone,
         var.project_id)}

    2. Configure kubectl for Cluster 2:
       ${format("gcloud container clusters get-credentials %s --zone %s --project %s",
         google_container_cluster.cluster2.name,
         var.cluster2_zone,
         var.project_id)}

    3. Test Filestore access from Cluster 1:
       kubectl --context gke_${var.project_id}_${var.cluster1_zone}_${var.cluster1_name} get pvc

    4. Test Filestore access from Cluster 2:
       kubectl --context gke_${var.project_id}_${var.cluster2_zone}_${var.cluster2_name} get pvc

    5. Filestore IP: ${google_filestore_instance.enterprise_shared.networks[0].ip_addresses[0]}

  EOT
  description = "Commands to test the multi-cluster setup"
}