resource "google_filestore_instance" "instance" {
  name     = "${var.cluster_name}-filestore"
  location = var.zone != "" ? var.zone : "${var.region}-a"
  tier     = var.filestore_tier

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = var.filestore_share_name

    nfs_export_options {
      ip_ranges   = [var.subnet_cidr]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network           = google_compute_network.vpc.name
    modes             = ["MODE_IPV4"]
    connect_mode      = "DIRECT_PEERING"
    reserved_ip_range = "${google_compute_global_address.filestore_range.address}/${google_compute_global_address.filestore_range.prefix_length}"
  }

  description = "Filestore instance for persistent storage in GKE cluster"

  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]
}

resource "kubernetes_storage_class" "filestore" {
  metadata {
    name = "filestore-csi"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "filestore.csi.storage.gke.io"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    tier               = var.filestore_tier
    network            = google_compute_network.vpc.name
    reserved-ipv4-cidr = "${google_compute_global_address.filestore_range.address}/${google_compute_global_address.filestore_range.prefix_length}"
  }

  depends_on = [
    google_container_cluster.primary,
    google_container_node_pool.primary_nodes
  ]
}