# Enterprise Filestore Instance - Shared between both clusters
resource "google_filestore_instance" "enterprise_shared" {
  name     = var.filestore_name
  location = var.region  # Regional for Enterprise tier
  tier     = var.filestore_tier

  # Multiple file shares - Enterprise tier supports this
  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = var.filestore_share_name

    nfs_export_options {
      ip_ranges   = [
        var.cluster1_subnet_cidr,
        var.cluster2_subnet_cidr,
        var.pods_cidr_cluster1,
        var.pods_cidr_cluster2
      ]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  # Second share for cluster-specific data (optional)
  file_shares {
    capacity_gb = 512  # Smaller share for cluster-specific data
    name        = var.filestore_share2_name

    nfs_export_options {
      ip_ranges   = [
        var.cluster1_subnet_cidr,
        var.cluster2_subnet_cidr,
        var.pods_cidr_cluster1,
        var.pods_cidr_cluster2
      ]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }

  networks {
    network           = google_compute_network.shared_vpc.name
    modes             = ["MODE_IPV4"]
    connect_mode      = "DIRECT_PEERING"
    reserved_ip_range = "${google_compute_global_address.filestore_range.address}/${google_compute_global_address.filestore_range.prefix_length}"
  }

  description = "Enterprise Filestore instance shared between two GKE clusters"

  labels = {
    tier        = "enterprise"
    environment = "multi-cluster-test"
    shared      = "true"
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]
}

# Static PV for Cluster 1 - Main Share
resource "kubernetes_persistent_volume" "cluster1_pv_main" {
  provider = kubernetes.cluster1

  metadata {
    name = "enterprise-filestore-pv-main-c1"
  }

  spec {
    capacity = {
      storage = "500Gi"
    }

    access_modes = ["ReadWriteMany"]

    persistent_volume_reclaim_policy = "Retain"
    storage_class_name                = ""

    persistent_volume_source {
      csi {
        driver        = "filestore.csi.storage.gke.io"
        volume_handle = "modeInstance/${var.region}/${var.filestore_name}/${var.filestore_share_name}"

        volume_attributes = {
          ip     = google_filestore_instance.enterprise_shared.networks[0].ip_addresses[0]
          volume = var.filestore_share_name
        }
      }
    }
  }

  depends_on = [
    google_container_cluster.cluster1,
    google_container_node_pool.cluster1_nodes,
    google_filestore_instance.enterprise_shared
  ]
}

# Static PV for Cluster 2 - Main Share
resource "kubernetes_persistent_volume" "cluster2_pv_main" {
  provider = kubernetes.cluster2

  metadata {
    name = "enterprise-filestore-pv-main-c2"
  }

  spec {
    capacity = {
      storage = "500Gi"
    }

    access_modes = ["ReadWriteMany"]

    persistent_volume_reclaim_policy = "Retain"
    storage_class_name                = ""

    persistent_volume_source {
      csi {
        driver        = "filestore.csi.storage.gke.io"
        volume_handle = "modeInstance/${var.region}/${var.filestore_name}/${var.filestore_share_name}"

        volume_attributes = {
          ip     = google_filestore_instance.enterprise_shared.networks[0].ip_addresses[0]
          volume = var.filestore_share_name
        }
      }
    }
  }

  depends_on = [
    google_container_cluster.cluster2,
    google_container_node_pool.cluster2_nodes,
    google_filestore_instance.enterprise_shared
  ]
}

# PVC for Cluster 1
resource "kubernetes_persistent_volume_claim" "cluster1_pvc" {
  provider = kubernetes.cluster1

  metadata {
    name      = "enterprise-filestore-pvc"
    namespace = "default"
  }

  spec {
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "500Gi"
      }
    }

    storage_class_name = ""
    volume_name        = kubernetes_persistent_volume.cluster1_pv_main.metadata[0].name
  }
}

# PVC for Cluster 2
resource "kubernetes_persistent_volume_claim" "cluster2_pvc" {
  provider = kubernetes.cluster2

  metadata {
    name      = "enterprise-filestore-pvc"
    namespace = "default"
  }

  spec {
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "500Gi"
      }
    }

    storage_class_name = ""
    volume_name        = kubernetes_persistent_volume.cluster2_pv_main.metadata[0].name
  }
}