# Storage Testing Guide for GKE + Filestore

This guide provides comprehensive instructions for testing storage capabilities, generating test data, and validating multi-pod access to your Filestore instance.

## Prerequisites

Ensure you have completed the main deployment and have kubectl configured:

```bash
gcloud container clusters get-credentials filestore-demo-cluster \
  --zone us-west1-a \
  --project your-project-id
```

## Quick Start - Automated Testing

Run the automated test script that handles everything:

```bash
./scripts/test-storage.sh
```

This script will:
1. Apply the PVC configuration
2. Generate 10GB of test data
3. Deploy verification pods
4. Show storage usage and file listings

## Manual Testing Steps

### Step 1: Apply Storage Configuration

```bash
# Apply the PV and PVC
kubectl apply -f k8s-manifests/static-pv-example.yaml

# Verify PVC is bound
kubectl get pvc filestore-pvc
```

### Step 2: Deploy Test Resources

```bash
# Deploy the data generator job and monitoring pod
kubectl apply -f k8s-manifests/storage-test-job.yaml

# Deploy the multi-replica test application
kubectl apply -f k8s-manifests/test-deployment.yaml
```

### Step 3: Generate Test Data

The `storage-test-job.yaml` creates a Kubernetes Job that generates:
- **10 x 1GB files** using `dd` command
- **Metadata files** with creation timestamps
- **Summary file** with generation details

Monitor the data generation:

```bash
# Follow job logs
kubectl logs -f job/generate-test-data

# Check job status
kubectl get jobs
```

## Data Generation Methods

### Method 1: Using Kubernetes Job (Recommended)

The included job automatically creates 10GB of test data:

```yaml
# This is already in storage-test-job.yaml
dd if=/dev/zero of=/data/testfile-${i}.dat bs=1M count=1024
```

### Method 2: Interactive Data Creation

Connect to a pod and create data manually:

```bash
# Connect to the storage reader pod
kubectl exec -it storage-reader -- sh

# Create a 5GB file with zeros (fast)
dd if=/dev/zero of=/data/large-file-5gb.dat bs=1M count=5120

# Create a 1GB file with random data (slower, more realistic)
dd if=/dev/urandom of=/data/random-1gb.dat bs=1M count=1024

# Create many small files
for i in $(seq 1 100); do
  echo "Test file $i created at $(date)" > /data/small-file-$i.txt
done

# Exit the pod
exit
```

### Method 3: Using a Custom Script

Create a pod that runs a custom data generation script:

```bash
kubectl run data-generator --image=busybox --rm -it --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "data-generator",
      "image": "busybox",
      "args": ["/bin/sh", "-c", "for i in 1 2 3 4 5; do dd if=/dev/zero of=/data/file-$i.dat bs=1M count=2048; done; ls -lh /data/"],
      "volumeMounts": [{
        "name": "storage",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "storage",
      "persistentVolumeClaim": {
        "claimName": "filestore-pvc"
      }
    }]
  }
}'
```

## Verification Commands

### Check Storage Usage

```bash
# View storage capacity and usage
kubectl exec storage-reader -- df -h /data

# Expected output:
# Filesystem      Size  Used Avail Use% Mounted on
# 10.98.117.18... 1007G  10G  997G   1% /data
```

### List Files Across Pods

```bash
# From the reader pod
kubectl exec storage-reader -- ls -lh /data/

# From the deployment (any replica)
kubectl exec deployment/filestore-test-app -- ls -lh /data/

# From a specific pod
POD=$(kubectl get pods -l app=filestore-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- ls -lh /data/
```

### Verify Multi-Pod Write Access

```bash
# Write from pod 1
kubectl exec deployment/filestore-test-app -- sh -c 'echo "Written from pod $(hostname)" > /data/test-write.txt'

# Read from pod 2
kubectl exec storage-reader -- cat /data/test-write.txt
```

## Performance Testing

### Sequential Write Test

```bash
kubectl exec -it storage-reader -- sh -c "time dd if=/dev/zero of=/data/perf-test.dat bs=1M count=1024"
```

### Random I/O Test with FIO

```bash
# Deploy FIO test pod
kubectl run fio-test --image=ljishen/fio --rm -it --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "fio",
      "image": "ljishen/fio",
      "args": ["--name=randwrite", "--ioengine=libaio", "--iodepth=16", "--rw=randwrite", "--bs=4k", "--size=1G", "--numjobs=4", "--runtime=60", "--group_reporting", "--filename=/data/fio-test"],
      "volumeMounts": [{
        "name": "storage",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "storage",
      "persistentVolumeClaim": {
        "claimName": "filestore-pvc"
      }
    }]
  }
}'
```

## Monitoring Storage

### Real-time Monitoring

```bash
# Watch storage usage
watch -n 5 'kubectl exec storage-reader -- df -h /data'

# Monitor file creation
kubectl logs -f storage-reader
```

### Check Filestore Instance Status

```bash
# View Filestore details
gcloud filestore instances describe filestore-demo-cluster-filestore \
  --location=us-west1-a \
  --format=json | jq '.fileShares[0]'

# Check operations
gcloud filestore operations list --location=us-west1-a
```

## Cleanup

### Remove Test Data Only

```bash
# Remove large test files
kubectl exec storage-reader -- sh -c 'rm -f /data/testfile-*.dat /data/*.info /data/SUMMARY.txt'

# Remove all .dat files
kubectl exec storage-reader -- sh -c 'rm -f /data/*.dat'
```

### Remove Test Pods

```bash
# Delete the job and its pods
kubectl delete job generate-test-data

# Delete the reader pod
kubectl delete pod storage-reader

# Delete the test deployment
kubectl delete deployment filestore-test-app
```

### Complete Cleanup

```bash
# Remove all test resources
kubectl delete -f k8s-manifests/storage-test-job.yaml
kubectl delete -f k8s-manifests/test-deployment.yaml
kubectl delete -f k8s-manifests/static-pv-example.yaml
```

## Troubleshooting

### Issue: Pod Can't Mount Volume

```bash
# Check PVC status
kubectl describe pvc filestore-pvc

# Check pod events
kubectl describe pod storage-reader

# Verify CSI driver
kubectl get pods -n kube-system | grep filestore-csi
```

### Issue: Permission Denied

```bash
# Check NFS export settings
kubectl exec storage-reader -- mount | grep nfs

# Test write permissions
kubectl exec storage-reader -- touch /data/test-permission.txt
```

### Issue: Slow Performance

Consider upgrading the Filestore tier:
- **BASIC_HDD**: 100 MB/s read, 100 MB/s write
- **BASIC_SSD**: 700 MB/s read, 350 MB/s write
- **HIGH_SCALE_SSD**: 920 MB/s read, 360 MB/s write
- **ENTERPRISE**: 1200 MB/s read, 600 MB/s write

## Advanced Scenarios

### Simulate Application Workload

```bash
# Create a workload simulator
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: workload-script
data:
  simulate.sh: |
    #!/bin/sh
    echo "Starting workload simulation..."
    while true; do
      # Write checkpoint files
      date > /data/checkpoint-\$(date +%s).txt

      # Append to log file
      echo "\$(date): Processing batch \$(hostname)" >> /data/app.log

      # Create temporary work files
      dd if=/dev/zero of=/data/work-\$(hostname).tmp bs=1M count=10 2>/dev/null
      sleep 5
      rm -f /data/work-\$(hostname).tmp

      sleep 10
    done
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload-simulator
spec:
  replicas: 3
  selector:
    matchLabels:
      app: simulator
  template:
    metadata:
      labels:
        app: simulator
    spec:
      containers:
      - name: simulator
        image: busybox
        command: ["/bin/sh", "/scripts/simulate.sh"]
        volumeMounts:
        - name: filestore
          mountPath: /data
        - name: script
          mountPath: /scripts
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: filestore-pvc
      - name: script
        configMap:
          name: workload-script
          defaultMode: 0755
EOF

# Monitor the workload
kubectl logs -l app=simulator --tail=10
```

### Backup Data to GCS

```bash
# Create a backup job
kubectl run backup-to-gcs --image=google/cloud-sdk:alpine --rm -it --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "backup",
      "image": "google/cloud-sdk:alpine",
      "command": ["/bin/sh", "-c"],
      "args": ["gsutil -m cp -r /data/* gs://your-backup-bucket/filestore-backup/"],
      "volumeMounts": [{
        "name": "storage",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "storage",
      "persistentVolumeClaim": {
        "claimName": "filestore-pvc"
      }
    }]
  }
}'
```

## Best Practices

1. **Data Organization**: Create subdirectories for different applications
   ```bash
   kubectl exec storage-reader -- mkdir -p /data/app1 /data/app2 /data/shared
   ```

2. **Regular Cleanup**: Implement log rotation and temporary file cleanup
   ```bash
   kubectl exec storage-reader -- find /data -name "*.tmp" -mtime +7 -delete
   ```

3. **Monitor Usage**: Set up alerts for storage capacity
   ```bash
   # Check if usage is above 80%
   kubectl exec storage-reader -- sh -c 'df /data | awk "NR==2 {if (\$5+0 > 80) print \"WARNING: Storage usage above 80%\"}"'
   ```

4. **Test Failure Scenarios**: Verify data persistence
   ```bash
   # Delete and recreate pods to ensure data persists
   kubectl delete pod storage-reader
   kubectl apply -f k8s-manifests/storage-test-job.yaml
   kubectl exec storage-reader -- ls -lh /data/
   ```

## Summary

This testing guide provides multiple methods to:
- Generate test data of various sizes
- Verify multi-pod access to shared storage
- Test performance characteristics
- Monitor storage usage
- Clean up test data

The Filestore instance provides reliable, persistent storage that remains available even when pods are deleted and recreated, making it ideal for stateful applications in GKE.