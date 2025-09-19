# GKE Cluster 1 - Zone: us-west1-a
resource "google_container_cluster" "cluster1" {
  name     = var.cluster1_name
  location = var.cluster1_zone

  network    = google_compute_network.shared_vpc.name
  subnetwork = google_compute_subnetwork.cluster1_subnet.name

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "cluster1-pods"
    services_secondary_range_name = "cluster1-services"
  }

  network_policy {
    enabled = true
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  description = "GKE Cluster 1 in zone ${var.cluster1_zone} with Filestore CSI driver"
}

# Node Pool for Cluster 1
resource "google_container_node_pool" "cluster1_nodes" {
  name       = "${var.cluster1_name}-node-pool"
  cluster    = google_container_cluster.cluster1.id
  node_count = var.node_count

  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.machine_type

    disk_size_gb = 100
    disk_type    = "pd-ssd"  # SSD for better performance

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      cluster = "cluster1"
      tier    = "enterprise-test"
    }
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# GKE Cluster 2 - Zone: us-west1-b
resource "google_container_cluster" "cluster2" {
  name     = var.cluster2_name
  location = var.cluster2_zone

  network    = google_compute_network.shared_vpc.name
  subnetwork = google_compute_subnetwork.cluster2_subnet.name

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "cluster2-pods"
    services_secondary_range_name = "cluster2-services"
  }

  network_policy {
    enabled = true
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  description = "GKE Cluster 2 in zone ${var.cluster2_zone} with Filestore CSI driver"
}

# Node Pool for Cluster 2
resource "google_container_node_pool" "cluster2_nodes" {
  name       = "${var.cluster2_name}-node-pool"
  cluster    = google_container_cluster.cluster2.id
  node_count = var.node_count

  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.machine_type

    disk_size_gb = 100
    disk_type    = "pd-ssd"  # SSD for better performance

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      cluster = "cluster2"
      tier    = "enterprise-test"
    }
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Service Account for Workload Identity (shared by both clusters)
resource "google_service_account" "workload_identity" {
  account_id   = "multi-cluster-wi-sa"
  display_name = "Workload Identity SA for Multi-Cluster Filestore Access"
  project      = var.project_id
}

# IAM binding for Cluster 1 workloads
resource "google_project_iam_member" "workload_identity_user_cluster1" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[default/filestore-app-cluster1]"

  depends_on = [
    google_container_cluster.cluster1,
    google_container_node_pool.cluster1_nodes
  ]
}

# IAM binding for Cluster 2 workloads
resource "google_project_iam_member" "workload_identity_user_cluster2" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[default/filestore-app-cluster2]"

  depends_on = [
    google_container_cluster.cluster2,
    google_container_node_pool.cluster2_nodes
  ]
}

# Service Account IAM bindings
resource "google_service_account_iam_member" "workload_identity_binding_cluster1" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/filestore-app-cluster1]"

  depends_on = [
    google_container_cluster.cluster1,
    google_container_node_pool.cluster1_nodes
  ]
}

resource "google_service_account_iam_member" "workload_identity_binding_cluster2" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/filestore-app-cluster2]"

  depends_on = [
    google_container_cluster.cluster2,
    google_container_node_pool.cluster2_nodes
  ]
}