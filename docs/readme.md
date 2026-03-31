# GKE + Filestore Test Drive

This repository provides a complete Terraform-based demo environment for testing Google Kubernetes Engine (GKE) with Google Filestore for persistent storage.

## Architecture Overview

This demo creates:
- **VPC Network**: Custom VPC with subnets for GKE cluster
- **GKE Cluster**: Kubernetes cluster with Filestore CSI driver enabled
- **Filestore Instance**: NFS-based managed file storage
- **Storage Class**: Kubernetes StorageClass for dynamic provisioning
- **Example Workloads**: Sample Kubernetes manifests for testing

## Prerequisites

1. **GCP Project**: Active GCP project with billing enabled
2. **Required APIs**: Enable the following APIs:
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable file.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   ```
3. **Tools**:
   - Terraform >= 1.0
   - gcloud CLI
   - kubectl

## Project Structure

```
.
├── provider.tf                  # Terraform and provider configuration
├── vpc.tf                       # VPC and networking resources
├── gke.tf                       # GKE cluster configuration
├── filestore.tf                 # Filestore instance and StorageClass
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── terraform.tfvars.example     # Example variables file
├── docs/storage-testing-guide.md     # Comprehensive storage testing guide
├── k8s-manifests/
│   ├── static-pv-example.yaml       # Static PV/PVC example
│   ├── dynamic-pvc-example.yaml     # Dynamic PVC example
│   ├── test-deployment.yaml         # Multi-pod deployment
│   ├── statefulset-example.yaml     # StatefulSet with shared storage
│   └── storage-test-job.yaml        # Job to generate 10GB test data
└── scripts/
    ├── deploy.sh                # Automated deployment script
    ├── cleanup.sh               # Resource cleanup script
    └── test-storage.sh          # Storage testing script (generates 10GB data)
```

## File Descriptions

### Terraform Files

- **provider.tf**: Configures Terraform providers (Google, Kubernetes)
- **vpc.tf**: Creates VPC network, subnet, and IP ranges for services
- **gke.tf**: Deploys GKE cluster with Workload Identity and CSI drivers
- **filestore.tf**: Provisions Filestore instance and Kubernetes StorageClass
- **variables.tf**: Defines all configurable parameters
- **outputs.tf**: Exports important resource information

### Kubernetes Manifests

- **static-pv-example.yaml**: Manual PV/PVC binding to existing Filestore
- **dynamic-pvc-example.yaml**: Dynamic volume provisioning using StorageClass
- **test-deployment.yaml**: Multi-replica deployment sharing storage
- **statefulset-example.yaml**: StatefulSet with both shared and pod-specific storage
- **storage-test-job.yaml**: Kubernetes Job to generate 10GB of test data

### Documentation

- **docs/storage-testing-guide.md**: Comprehensive guide for storage testing, data generation, and verification

## Quick Start

### 1. Configure Terraform Variables

Copy and update the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your project details:
```hcl
project_id = "your-gcp-project-id"
region     = "us-west1"      # Default region
zone       = "us-west1-a"    # Default zone
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply configuration
terraform apply
```

Or use the automated deployment script:
```bash
./scripts/deploy.sh your-gcp-project-id
```

### 3. Configure kubectl

After deployment, configure kubectl access:
```bash
gcloud container clusters get-credentials filestore-demo-cluster \
  --zone us-west1-a \
  --project your-gcp-project-id
```

Note: Use `--zone` instead of `--region` since we're deploying a zonal cluster.

### 4. Deploy Test Applications

#### Option A: Use Static Provisioning
```bash
# Get Filestore IP from Terraform output
FILESTORE_IP=$(terraform output -raw filestore_ip_address)

# The PV manifest already has the IP configured, but you can verify/update it:
# sed -i "s/10.98.117.18/$FILESTORE_IP/g" k8s-manifests/static-pv-example.yaml

# Apply manifests
kubectl apply -f k8s-manifests/static-pv-example.yaml
kubectl apply -f k8s-manifests/test-deployment.yaml
```

#### Option B: Use Dynamic Provisioning
```bash
kubectl apply -f k8s-manifests/dynamic-pvc-example.yaml
```

### 5. Verify Deployment

```bash
# Check PVC status
kubectl get pvc

# Check pod status
kubectl get pods

# View shared storage writes
kubectl exec -it deployment/filestore-test-app -- cat /data/test-file.txt

# Get LoadBalancer IP
kubectl get svc filestore-test-service
```

## Configuration Options

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Name of GKE cluster | `filestore-demo-cluster` |
| `machine_type` | VM type for nodes | `n2-standard-2` |
| `node_count` | Initial node count | `2` |
| `filestore_tier` | Filestore performance tier | `BASIC_HDD` |
| `filestore_capacity_gb` | Storage capacity (GB) | `1024` |
| `preemptible_nodes` | Use preemptible VMs | `true` |

### Filestore Tiers

- **BASIC_HDD**: Cost-effective, 1TB minimum
- **BASIC_SSD**: Higher performance, 2.5TB minimum
- **HIGH_SCALE_SSD**: Multi-share, 10TB minimum
- **ENTERPRISE**: Highest performance, 1TB minimum

## Testing Scenarios

### Quick Storage Test (Generate 10GB Test Data)

Run the automated storage test to generate 10GB of test data and verify multi-pod access:

```bash
./scripts/test-storage.sh
```

This will:
- Generate 10 x 1GB files using `dd` command
- Create metadata and summary files
- Deploy multiple pods to verify shared access
- Show storage usage and file listings

For detailed testing instructions, see: **[📖 storage-testing-guide.md](docs/storage-testing-guide.md)**

### Additional Testing Scenarios

### 1. Multi-Pod Read/Write
Deploy the test deployment to verify multiple pods can read/write simultaneously:
```bash
kubectl apply -f k8s-manifests/test-deployment.yaml
kubectl scale deployment filestore-test-app --replicas=5
```

### 2. StatefulSet with Shared Storage
Test StatefulSet pods sharing a common Filestore volume:
```bash
kubectl apply -f k8s-manifests/statefulset-example.yaml
kubectl exec filestore-statefulset-0 -- cat /data/shared/startup-log.txt
```

### 3. Interactive Data Creation
```bash
# Connect to a pod and create test files
kubectl exec -it storage-reader -- sh

# Create a 5GB file
dd if=/dev/zero of=/data/large-file.dat bs=1M count=5120

# Verify from another pod
kubectl exec deployment/filestore-test-app -- ls -lh /data/
```

## Monitoring

### View Filestore Metrics
```bash
gcloud filestore instances describe filestore-demo-cluster-filestore \
  --location=us-west1-a \
  --format="table(name,tier,fileShares[0].name,fileShares[0].capacityGb,state)"
```

### Check CSI Driver
```bash
kubectl get csidrivers
kubectl get csinodes
```

## Troubleshooting

### Common Issues

1. **PVC Stuck in Pending**
   - Check StorageClass: `kubectl describe storageclass filestore-csi`
   - Verify CSI driver: `kubectl get pods -n kube-system | grep filestore`

2. **Mount Failures**
   - Check network connectivity between GKE and Filestore
   - Verify firewall rules allow NFS traffic (ports 111, 2049)

3. **Permission Denied**
   - Check NFS export options in Filestore configuration
   - Verify `squash_mode` is set to `NO_ROOT_SQUASH`

### Debug Commands
```bash
# Check CSI driver logs
kubectl logs -n kube-system -l app=gcp-filestore-csi-driver

# Describe PVC events
kubectl describe pvc filestore-pvc

# Test NFS mount manually
kubectl run test-nfs --rm -it --image=busybox -- \
  sh -c "ping -c 3 FILESTORE_IP && nc -zv FILESTORE_IP 2049"
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

Or use the cleanup script:
```bash
./scripts/cleanup.sh
```

## Cost Considerations

- **GKE Cluster**: ~$72/month for control plane
- **Node Pool**: Variable based on machine type and count
- **Filestore**: Starting at ~$204/month for 1TB BASIC_HDD
- **Network**: Egress charges apply for external traffic

Use preemptible nodes and BASIC_HDD tier for cost optimization in test environments.

## Security Best Practices

1. **Network Isolation**: Resources deployed in private VPC
2. **Workload Identity**: Enabled for secure pod authentication
3. **Private IP**: Filestore uses private IP addressing
4. **IAM**: Service accounts with minimal required permissions

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Filestore Documentation](https://cloud.google.com/filestore/docs)
- [Filestore CSI Driver](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/filestore-csi-driver)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## Contributing

Feel free to submit issues or pull requests for improvements.

## License

MIT License - See LICENSE file for details