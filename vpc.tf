resource "google_compute_network" "vpc" {
  name                            = "${var.cluster_name}-vpc"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false

  description = "VPC network for GKE cluster and Filestore instance"
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.cluster_name}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  description = "Subnet for GKE cluster nodes with secondary ranges for pods and services"
}

resource "google_compute_global_address" "filestore_range" {
  name          = "${var.cluster_name}-filestore-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 29
  network       = google_compute_network.vpc.id

  description = "IP address range for Filestore instance"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.filestore_range.name]
}