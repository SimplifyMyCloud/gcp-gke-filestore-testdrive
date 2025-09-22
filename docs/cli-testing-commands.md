# CLI Commands for Testing Multi-Cluster Filestore

This document provides CLI commands to manually test file sharing between the two GKE clusters using the shared Enterprise Filestore.

## Prerequisites

Ensure you have:
- `gcloud` CLI installed and authenticated
- `kubectl` installed
- Both GKE clusters deployed
- PVCs created (using `./create-pvcs.sh` if needed)

## Basic Configuration

```bash
PROJECT_ID="simplifymycloud-dev"
CLUSTER1_ZONE="us-west1-a"
CLUSTER2_ZONE="us-west1-b"
```

## Step-by-Step Interactive Testing

### Step 1: Write a file from Cluster 1

```bash
# Connect to Cluster 1
gcloud container clusters get-credentials filestore-cluster-1 \
  --zone us-west1-a \
  --project simplifymycloud-dev

# Create a pod with the Filestore mounted
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-cluster1
spec:
  containers:
  - name: test-cluster1
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: filestore
      mountPath: /data
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF

# Exec into the pod
kubectl exec -it test-cluster1 -- sh

# Inside the pod, run these commands:
echo "Hello from Cluster 1 - $(date)" > /data/shared-file.txt
echo "Adding some test data..." >> /data/shared-file.txt
cat /data/shared-file.txt
ls -la /data/
exit

# Clean up the pod when done
kubectl delete pod test-cluster1
```

### Step 2: Read and modify the file from Cluster 2

```bash
# Connect to Cluster 2
gcloud container clusters get-credentials filestore-cluster-2 \
  --zone us-west1-b \
  --project simplifymycloud-dev

# Create a pod with the Filestore mounted
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-cluster2
spec:
  containers:
  - name: test-cluster2
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: filestore
      mountPath: /data
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF

# Exec into the pod
kubectl exec -it test-cluster2 -- sh

# Inside the pod, you should see the file from Cluster 1:
cat /data/shared-file.txt
echo "Hello from Cluster 2 - $(date)" >> /data/shared-file.txt
cat /data/shared-file.txt
ls -la /data/
exit

# Clean up the pod when done
kubectl delete pod test-cluster2
```

### Step 3: Verify changes from Cluster 1

```bash
# Switch back to Cluster 1
gcloud container clusters get-credentials filestore-cluster-1 \
  --zone us-west1-a \
  --project simplifymycloud-dev

# Quick check to see the file content
kubectl run check-cluster1 --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"check-cluster1","image":"busybox","volumeMounts":[{"name":"filestore","mountPath":"/data"}]}],"volumes":[{"name":"filestore","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- cat /data/shared-file.txt
```

## One-Liner Commands for Quick Testing

### Write from Cluster 1
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
kubectl run write-test --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"write-test","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- sh -c "echo 'Test at $(date)' > /data/test.txt && cat /data/test.txt"
```

### Read from Cluster 2
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2
kubectl run read-test --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"read-test","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- cat /data/test.txt
```

## Large File Testing

### Create a 100MB test file from Cluster 1
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
kubectl run create-large --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"create-large","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- sh -c "dd if=/dev/zero of=/data/100mb-test.dat bs=1M count=100 && ls -lh /data/"
```

### Verify from Cluster 2
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2
kubectl run check-large --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"check-large","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- ls -lh /data/
```

## Real-Time Monitoring

Run these commands in separate terminal windows to see real-time synchronization:

### Terminal 1 - Continuous writer in Cluster 1
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
kubectl run writer --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"writer","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- sh -c "while true; do echo 'Cluster 1: $(date)' >> /data/live.log; sleep 2; done"
```

### Terminal 2 - Watch from Cluster 2
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2
kubectl run watcher --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"watcher","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- tail -f /data/live.log
```

## Performance Testing

### Write performance test from Cluster 1
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
kubectl run perf-write --image=ubuntu:22.04 --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"perf-write","image":"ubuntu:22.04","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- bash -c "apt-get update && apt-get install -y fio && cd /data && fio --name=write_test --ioengine=libaio --rw=write --bs=1M --size=1G --numjobs=1 --runtime=60 --group_reporting"
```

### Read performance test from Cluster 2
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2
kubectl run perf-read --image=ubuntu:22.04 --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"perf-read","image":"ubuntu:22.04","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- bash -c "apt-get update && apt-get install -y fio && cd /data && fio --name=read_test --ioengine=libaio --rw=read --bs=1M --size=1G --numjobs=1 --runtime=60 --group_reporting"
```

## Concurrent Access Testing

### Create multiple writers in Cluster 1
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
for i in {1..3}; do
  kubectl run writer-$i --image=busybox \
    --overrides='{"spec":{"containers":[{"name":"writer-'$i'","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
    -- sh -c "while true; do echo 'Writer $i from Cluster 1: $(date)' >> /data/concurrent.log; sleep 3; done" &
done
```

### Create multiple readers in Cluster 2
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2
for i in {1..3}; do
  kubectl run reader-$i --image=busybox \
    --overrides='{"spec":{"containers":[{"name":"reader-'$i'","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
    -- sh -c "while true; do tail -5 /data/concurrent.log; sleep 5; done" &
done
```

## Cleanup Commands

### Delete test pods from Cluster 1
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
kubectl delete pods --all --ignore-not-found=true
```

### Delete test pods from Cluster 2
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2
kubectl delete pods --all --ignore-not-found=true
```

### Clean up test files
```bash
kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1
kubectl run cleanup --image=busybox --rm --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"cleanup","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
  -- sh -c "cd /data && rm -f *.txt *.dat *.log && echo 'Test files cleaned up' && ls -la"
```

## Useful Aliases

Add these to your `.bashrc` or `.zshrc` for quicker testing:

```bash
# Quick context switches
alias kc1='kubectl config use-context gke_simplifymycloud-dev_us-west1-a_filestore-cluster-1'
alias kc2='kubectl config use-context gke_simplifymycloud-dev_us-west1-b_filestore-cluster-2'

# Quick pod with mounted filestore
function kfs() {
  cat <<EOF | kubectl apply -f - && kubectl exec -it fs-test -- sh && kubectl delete pod fs-test
apiVersion: v1
kind: Pod
metadata:
  name: fs-test
spec:
  containers:
  - name: fs-test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: filestore
      mountPath: /data
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF
}

# Quick file check
function kcheck() {
  kubectl run check --image=busybox --rm --restart=Never \
    --overrides='{"spec":{"containers":[{"name":"check","image":"busybox","volumeMounts":[{"name":"fs","mountPath":"/data"}]}],"volumes":[{"name":"fs","persistentVolumeClaim":{"claimName":"enterprise-filestore-pvc"}}]}}' \
    -- ls -la /data/
}
```

## Tips

1. **Use `--rm` flag**: Automatically removes pods after execution
2. **Use `--restart=Never`**: Prevents pods from restarting on failure
3. **Check PVC status**: `kubectl get pvc` to ensure volumes are bound
4. **Monitor events**: `kubectl get events --sort-by='.lastTimestamp'` to troubleshoot issues
5. **Check pod logs**: `kubectl logs <pod-name>` to see output
6. **Describe resources**: `kubectl describe pvc enterprise-filestore-pvc` for detailed info

## Expected Results

- Files created in Cluster 1 are immediately visible in Cluster 2
- Changes made in either cluster are instantly reflected in the other
- Multiple pods can read/write simultaneously without conflicts
- Performance should be consistent across both clusters

## Troubleshooting

If files aren't visible across clusters:
1. Check PVC status: `kubectl get pvc`
2. Check PV status: `kubectl get pv`
3. Verify Filestore instance: `gcloud filestore instances list --region=us-west1`
4. Check pod events: `kubectl describe pod <pod-name>`
5. Verify network connectivity between clusters and Filestore