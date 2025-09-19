# Shared VPC for both GKE clusters and Enterprise Filestore
resource "google_compute_network" "shared_vpc" {
  name                            = "multi-cluster-shared-vpc"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false

  description = "Shared VPC network for multi-cluster GKE and Enterprise Filestore"
}

# Subnet for Cluster 1 (us-west1-a)
resource "google_compute_subnetwork" "cluster1_subnet" {
  name                     = "${var.cluster1_name}-subnet"
  ip_cidr_range            = var.cluster1_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.shared_vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "cluster1-pods"
    ip_cidr_range = var.pods_cidr_cluster1
  }

  secondary_ip_range {
    range_name    = "cluster1-services"
    ip_cidr_range = var.services_cidr_cluster1
  }

  description = "Subnet for GKE cluster 1 with secondary ranges for pods and services"
}

# Subnet for Cluster 2 (us-west1-b)
resource "google_compute_subnetwork" "cluster2_subnet" {
  name                     = "${var.cluster2_name}-subnet"
  ip_cidr_range            = var.cluster2_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.shared_vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "cluster2-pods"
    ip_cidr_range = var.pods_cidr_cluster2
  }

  secondary_ip_range {
    range_name    = "cluster2-services"
    ip_cidr_range = var.services_cidr_cluster2
  }

  description = "Subnet for GKE cluster 2 with secondary ranges for pods and services"
}

# Reserved IP range for private service connection (required for service networking)
resource "google_compute_global_address" "service_networking_range" {
  name          = "service-networking-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.shared_vpc.id

  description = "IP address range for private service connection"
}

# Reserved IP range for Enterprise Filestore
resource "google_compute_global_address" "filestore_range" {
  name          = "enterprise-filestore-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 29
  network       = google_compute_network.shared_vpc.id

  description = "IP address range for Enterprise Filestore instance"
}

# Service networking connection for private Google services
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.shared_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.service_networking_range.name]
}

# Firewall rule to allow internal communication between clusters
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-multi-cluster"
  network = google_compute_network.shared_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.cluster1_subnet_cidr,
    var.cluster2_subnet_cidr,
    var.pods_cidr_cluster1,
    var.pods_cidr_cluster2,
    "10.98.0.0/16"  # Reserved for internal services
  ]

  description = "Allow internal communication between both clusters and Filestore"
}

# Firewall rule specifically for NFS traffic
resource "google_compute_firewall" "allow_nfs" {
  name    = "allow-nfs-filestore"
  network = google_compute_network.shared_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["111", "2049", "20048"]
  }

  allow {
    protocol = "udp"
    ports    = ["111", "2049", "20048"]
  }

  source_ranges = [
    var.cluster1_subnet_cidr,
    var.cluster2_subnet_cidr,
    var.pods_cidr_cluster1,
    var.pods_cidr_cluster2
  ]

  description = "Allow NFS traffic for Filestore access from both clusters"
}