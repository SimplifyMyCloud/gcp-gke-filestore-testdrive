# Multi-Cluster Filestore Testing Guide

This guide provides step-by-step instructions for testing file sharing between two GKE clusters using Google Filestore Enterprise.

## Architecture Overview

- **2 GKE Clusters**: Both clusters in the same region but different zones
- **1 Shared Filestore Enterprise Instance**: Accessible by both clusters
- **Shared VPC**: Both clusters use the same VPC network
- **Persistent Volumes**: Each cluster has PV/PVC configured to mount the same Filestore share

## Prerequisites

Ensure your Terraform deployment is complete:
```bash
terraform apply
```

## Step 1: Configure kubectl Contexts

Set up kubectl access to both clusters:

```bash
# Get credentials for Cluster 1
gcloud container clusters get-credentials filestore-cluster-1 \
  --zone us-west1-a \
  --project $(terraform output -raw project_id)

# Rename context for clarity
kubectl config rename-context gke_$(terraform output -raw project_id)_us-west1-a_filestore-cluster-1 cluster1

# Get credentials for Cluster 2
gcloud container clusters get-credentials filestore-cluster-2 \
  --zone us-west1-b \
  --project $(terraform output -raw project_id)

# Rename context for clarity
kubectl config rename-context gke_$(terraform output -raw project_id)_us-west1-b_filestore-cluster-2 cluster2
```

Verify contexts:
```bash
kubectl config get-contexts
```

## Step 2: Deploy Test Workloads

### Deploy Writer Pod to Cluster 1

Create a pod that will write test files to the shared Filestore:

```bash
# Switch to Cluster 1
kubectl config use-context cluster1

# Create writer deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filestore-writer
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filestore-writer
  template:
    metadata:
      labels:
        app: filestore-writer
    spec:
      containers:
      - name: writer
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do date >> /data/cluster1-writes.txt; echo 'Cluster 1 wrote at:' \$(date) >> /data/shared-log.txt; sleep 10; done"]
        volumeMounts:
        - name: filestore
          mountPath: /data
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: enterprise-filestore-pvc
EOF

# Verify the writer pod is running
kubectl get pods -l app=filestore-writer
```

### Deploy Reader Pod to Cluster 2

Create a pod that will read files from the shared Filestore:

```bash
# Switch to Cluster 2
kubectl config use-context cluster2

# Create reader deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filestore-reader
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: filestore-reader
  template:
    metadata:
      labels:
        app: filestore-reader
    spec:
      containers:
      - name: reader
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "while true; do date >> /data/cluster2-writes.txt; echo 'Cluster 2 wrote at:' \$(date) >> /data/shared-log.txt; sleep 10; done"]
        volumeMounts:
        - name: filestore
          mountPath: /data
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: enterprise-filestore-pvc
EOF

# Verify the reader pod is running
kubectl get pods -l app=filestore-reader
```

## Step 3: Create Test Files from Cluster 1

### Create Large Test Files

```bash
# Switch to Cluster 1
kubectl config use-context cluster1

# Create an interactive test pod
kubectl run test-writer --rm -i --tty --image=ubuntu:22.04 -- bash

# Inside the pod, install tools and create test files
apt-get update && apt-get install -y curl vim
cd /data

# Create a 1GB test file
dd if=/dev/zero of=test-file-1gb.dat bs=1M count=1024

# Create a directory structure with sample files
mkdir -p shared-project/documents
mkdir -p shared-project/configs
mkdir -p shared-project/logs

# Create some test documents
echo "This file was created by Cluster 1 at $(date)" > shared-project/documents/readme.txt
echo "Project configuration v1.0" > shared-project/configs/config.yaml
echo "Application started at $(date)" > shared-project/logs/app.log

# Create a file with cluster identification
hostname > cluster1-hostname.txt
echo "Files created by Cluster 1:" > file-manifest.txt
ls -la >> file-manifest.txt

# Create a collaborative document
cat > collaborative-doc.txt <<EOL
===== COLLABORATIVE DOCUMENT =====
This document is shared between Cluster 1 and Cluster 2

[Cluster 1 Entry - $(date)]
Hello from Cluster 1! We're writing to the shared Filestore.
Our hostname is: $(hostname)
Our IP is: $(hostname -i)

Please add your entries below:
================================
EOL

# Exit the pod (press Ctrl+D or type exit)
exit
```

### Generate Dataset with Multiple Files

```bash
# Create a job to generate multiple test files
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-generator-cluster1
spec:
  template:
    spec:
      containers:
      - name: generator
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          echo "Starting data generation from Cluster 1..."
          cd /data

          # Create 10 test files of 100MB each
          for i in \$(seq 1 10); do
            dd if=/dev/zero of=cluster1-file-\${i}.dat bs=1M count=100
            echo "Created cluster1-file-\${i}.dat (100MB)"
          done

          # Create metadata file
          echo "Data Generation Report - Cluster 1" > cluster1-metadata.txt
          echo "Generated at: \$(date)" >> cluster1-metadata.txt
          echo "Total files: 10" >> cluster1-metadata.txt
          echo "Total size: 1GB" >> cluster1-metadata.txt
          ls -lh cluster1-file-*.dat >> cluster1-metadata.txt

          echo "Data generation complete!"
        volumeMounts:
        - name: filestore
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: enterprise-filestore-pvc
  backoffLimit: 1
EOF

# Watch the job progress
kubectl get job data-generator-cluster1 -w
```

## Step 4: Access Files from Cluster 2

### Read Files Created by Cluster 1

```bash
# Switch to Cluster 2
kubectl config use-context cluster2

# Create an interactive pod to explore files
kubectl run test-reader --rm -i --tty --image=ubuntu:22.04 -- bash

# Inside the pod, explore the shared files
apt-get update && apt-get install -y tree
cd /data

# List all files
ls -la

# View the collaborative document
cat collaborative-doc.txt

# Append to the collaborative document
cat >> collaborative-doc.txt <<EOL

[Cluster 2 Entry - $(date)]
Hello from Cluster 2! We can see and access all files from Cluster 1.
Our hostname is: $(hostname)
Our IP is: $(hostname -i)

Files we can see from Cluster 1:
$(ls -lh cluster1-* 2>/dev/null | head -5)

We're now adding our own content to demonstrate bidirectional access.
================================
EOL

# Check file sizes
du -sh *

# View directory structure
tree shared-project/

# Create response files from Cluster 2
echo "This file was created by Cluster 2 at $(date)" > cluster2-response.txt
echo "Cluster 2 hostname: $(hostname)" > cluster2-hostname.txt

# Verify Cluster 1's files
if [ -f test-file-1gb.dat ]; then
  echo "SUCCESS: Can access 1GB file from Cluster 1"
  ls -lh test-file-1gb.dat
fi

# Exit the pod
exit
```

### Simultaneous Read/Write Test

```bash
# Deploy a reader that continuously monitors changes
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: file-monitor
spec:
  containers:
  - name: monitor
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Starting file monitor on Cluster 2..."
      while true; do
        echo "=== File System Status at \$(date) ==="
        ls -la /data/*.txt 2>/dev/null | tail -5
        echo "=== Last 5 lines of shared-log.txt ==="
        tail -5 /data/shared-log.txt 2>/dev/null
        echo "=== Storage Usage ==="
        df -h /data
        echo "---"
        sleep 30
      done
    volumeMounts:
    - name: filestore
      mountPath: /data
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF

# View the monitor logs
kubectl logs -f file-monitor
```

## Step 5: Performance Testing

### Write Performance Test from Cluster 1

```bash
kubectl config use-context cluster1

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: write-performance-test
spec:
  template:
    spec:
      containers:
      - name: perf-test
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          apt-get update && apt-get install -y fio
          cd /data

          echo "Running write performance test..."
          fio --name=write_test \
              --ioengine=libaio \
              --rw=write \
              --bs=1M \
              --size=1G \
              --numjobs=1 \
              --runtime=60 \
              --group_reporting \
              --output=cluster1_write_performance.txt

          echo "Write test complete. Results saved to cluster1_write_performance.txt"
        volumeMounts:
        - name: filestore
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: enterprise-filestore-pvc
  backoffLimit: 1
EOF
```

### Read Performance Test from Cluster 2

```bash
kubectl config use-context cluster2

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: read-performance-test
spec:
  template:
    spec:
      containers:
      - name: perf-test
        image: ubuntu:22.04
        command: ["/bin/bash"]
        args:
        - -c
        - |
          apt-get update && apt-get install -y fio
          cd /data

          # Wait for write test file to be available
          while [ ! -f cluster1_write_performance.txt ]; do
            echo "Waiting for Cluster 1 write test to complete..."
            sleep 10
          done

          echo "Running read performance test..."
          fio --name=read_test \
              --ioengine=libaio \
              --rw=read \
              --bs=1M \
              --size=1G \
              --numjobs=1 \
              --runtime=60 \
              --group_reporting \
              --output=cluster2_read_performance.txt

          echo "Read test complete. Results saved to cluster2_read_performance.txt"
        volumeMounts:
        - name: filestore
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: enterprise-filestore-pvc
  backoffLimit: 1
EOF
```

## Step 6: Verify Cross-Cluster Access

### Verification Script

Create a comprehensive verification script:

```bash
# Run from your local machine
cat > verify-filestore-sharing.sh <<'EOF'
#!/bin/bash

echo "===== Multi-Cluster Filestore Verification ====="
echo ""

# Check Cluster 1
echo "=== CLUSTER 1 STATUS ==="
kubectl config use-context cluster1
echo "Pods in Cluster 1:"
kubectl get pods
echo ""
echo "Files created by Cluster 1:"
kubectl exec deployment/filestore-writer -- ls -la /data/ | grep cluster1
echo ""

# Check Cluster 2
echo "=== CLUSTER 2 STATUS ==="
kubectl config use-context cluster2
echo "Pods in Cluster 2:"
kubectl get pods
echo ""
echo "Files visible in Cluster 2:"
kubectl exec deployment/filestore-reader -- ls -la /data/
echo ""

# Check shared log
echo "=== SHARED LOG ENTRIES ==="
echo "Last 10 entries in shared log:"
kubectl exec deployment/filestore-reader -- tail -10 /data/shared-log.txt
echo ""

# Storage usage
echo "=== STORAGE USAGE ==="
kubectl exec deployment/filestore-reader -- df -h /data
echo ""

echo "===== Verification Complete ====="
EOF

chmod +x verify-filestore-sharing.sh
./verify-filestore-sharing.sh
```

## Step 7: Advanced Testing Scenarios

### Concurrent Write Test

Test multiple pods writing simultaneously from both clusters:

```bash
# Scale writers in Cluster 1
kubectl config use-context cluster1
kubectl scale deployment filestore-writer --replicas=3

# Scale writers in Cluster 2
kubectl config use-context cluster2
kubectl scale deployment filestore-reader --replicas=3

# Monitor file creation
watch "kubectl exec deployment/filestore-reader -- ls -la /data/*.txt | wc -l"
```

### File Locking Test

```bash
# Create a file locking test pod in Cluster 1
kubectl config use-context cluster1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: lock-test-cluster1
spec:
  containers:
  - name: lock-test
    image: ubuntu:22.04
    command: ["/bin/bash"]
    args:
    - -c
    - |
      apt-get update && apt-get install -y python3
      cd /data
      python3 <<'PY'
      import fcntl
      import time
      import os

      hostname = os.popen('hostname').read().strip()

      with open('locked-file.txt', 'a') as f:
          print(f"Cluster 1 ({hostname}) acquiring lock...")
          fcntl.flock(f, fcntl.LOCK_EX)
          print("Lock acquired!")

          f.write(f"Cluster 1 ({hostname}) held lock at {time.ctime()}\n")
          f.flush()

          print("Holding lock for 30 seconds...")
          time.sleep(30)

          print("Releasing lock...")

      print("Lock released!")
      PY
    volumeMounts:
    - name: filestore
      mountPath: /data
  restartPolicy: Never
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF
```

## Step 8: Cleanup

### Remove Test Resources

```bash
# Clean up Cluster 1 resources
kubectl config use-context cluster1
kubectl delete deployment filestore-writer
kubectl delete job data-generator-cluster1
kubectl delete job write-performance-test
kubectl delete pod lock-test-cluster1 --ignore-not-found=true
kubectl delete pod test-writer --ignore-not-found=true

# Clean up Cluster 2 resources
kubectl config use-context cluster2
kubectl delete deployment filestore-reader
kubectl delete pod file-monitor
kubectl delete job read-performance-test
kubectl delete pod test-reader --ignore-not-found=true

# Verify cleanup
kubectl config use-context cluster1
kubectl get all

kubectl config use-context cluster2
kubectl get all
```

### Clean Test Data (Optional)

```bash
# Create a cleanup job in either cluster
kubectl config use-context cluster1

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-test-data
spec:
  template:
    spec:
      containers:
      - name: cleanup
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          cd /data
          echo "Cleaning up test data..."
          rm -f *.dat *.txt
          rm -rf shared-project/
          echo "Cleanup complete!"
          ls -la
        volumeMounts:
        - name: filestore
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: filestore
        persistentVolumeClaim:
          claimName: enterprise-filestore-pvc
  backoffLimit: 1
EOF

kubectl wait --for=condition=complete job/cleanup-test-data --timeout=60s
kubectl delete job cleanup-test-data
```

## Troubleshooting

### Common Issues and Solutions

1. **PVC Not Bound**
   ```bash
   # Check PVC status in both clusters
   kubectl config use-context cluster1
   kubectl describe pvc enterprise-filestore-pvc

   kubectl config use-context cluster2
   kubectl describe pvc enterprise-filestore-pvc
   ```

2. **Mount Permission Denied**
   ```bash
   # Verify Filestore export settings
   gcloud filestore instances describe $(terraform output -raw filestore_instance_name) \
     --location=$(terraform output -raw region) \
     --format=json | jq '.fileShares[0].nfsExportOptions'
   ```

3. **Network Connectivity Issues**
   ```bash
   # Test connectivity from pod to Filestore
   kubectl run test-connectivity --rm -it --image=busybox -- \
     sh -c "ping -c 3 $(terraform output -raw filestore_ip_address)"
   ```

4. **Performance Issues**
   ```bash
   # Check Filestore metrics
   gcloud monitoring metrics-descriptors list --filter="metric.type:file.googleapis.com"
   ```

## Summary

This testing demonstrates:
- ✅ Files created in Cluster 1 are immediately visible in Cluster 2
- ✅ Both clusters can read and write to the same Filestore instance
- ✅ File locking works across clusters
- ✅ Performance is consistent across both clusters
- ✅ Large files (1GB+) can be shared efficiently
- ✅ Multiple pods can access the storage simultaneously

## Next Steps

1. **Production Considerations**:
   - Implement backup strategies
   - Set up monitoring and alerting
   - Configure quotas and limits
   - Plan for disaster recovery

2. **Advanced Configurations**:
   - Test with different Filestore tiers
   - Implement access controls
   - Set up automated data lifecycle policies
   - Configure cross-region replication

3. **Application Integration**:
   - Deploy stateful applications
   - Test database workloads
   - Implement shared cache layers
   - Set up CI/CD pipeline artifacts storage