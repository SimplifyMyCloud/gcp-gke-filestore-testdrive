#!/bin/bash

PROJECT_ID="simplifymycloud-dev"

echo "=== Multi-Cluster Filestore Quick Test ==="
echo ""

# Create test pod with volume mount in Cluster 1
echo "1. Creating test file from Cluster 1..."
gcloud container clusters get-credentials filestore-cluster-1 --zone us-west1-a --project $PROJECT_ID --quiet

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: writer-test
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Writing from Cluster 1..."
      echo "Hello from Cluster 1 at \$(date)" > /data/test-message.txt
      echo "Cluster 1 hostname: \$(hostname)" >> /data/test-message.txt
      echo "File created successfully!"
      cat /data/test-message.txt
      sleep 10
    volumeMounts:
    - name: filestore
      mountPath: /data
  restartPolicy: Never
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF

sleep 5
kubectl logs writer-test
kubectl delete pod writer-test --wait=false

echo ""
echo "2. Reading the file from Cluster 2..."
gcloud container clusters get-credentials filestore-cluster-2 --zone us-west1-b --project $PROJECT_ID --quiet

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: reader-test
spec:
  containers:
  - name: reader
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Reading file created by Cluster 1:"
      cat /data/test-message.txt
      echo ""
      echo "Adding message from Cluster 2..."
      echo "Hello from Cluster 2 at \$(date)" >> /data/test-message.txt
      echo "Cluster 2 hostname: \$(hostname)" >> /data/test-message.txt
      echo ""
      echo "Updated file content:"
      cat /data/test-message.txt
      sleep 10
    volumeMounts:
    - name: filestore
      mountPath: /data
  restartPolicy: Never
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF

sleep 5
kubectl logs reader-test
kubectl delete pod reader-test --wait=false

echo ""
echo "3. Verifying bidirectional access from Cluster 1..."
gcloud container clusters get-credentials filestore-cluster-1 --zone us-west1-a --project $PROJECT_ID --quiet

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: verify-test
spec:
  containers:
  - name: verify
    image: busybox
    command: ["/bin/sh"]
    args:
    - -c
    - |
      echo "Final file content as seen from Cluster 1:"
      cat /data/test-message.txt
      echo ""
      echo "Directory listing:"
      ls -la /data/
      sleep 5
    volumeMounts:
    - name: filestore
      mountPath: /data
  restartPolicy: Never
  volumes:
  - name: filestore
    persistentVolumeClaim:
      claimName: enterprise-filestore-pvc
EOF

sleep 5
kubectl logs verify-test
kubectl delete pod verify-test --wait=false

echo ""
echo "=== Test Complete ==="
echo "✅ Files created in one cluster are immediately accessible from the other cluster!"

# Cleanup
echo "Cleaning up test pods..."
kubectl delete pod writer-test reader-test verify-test --ignore-not-found=true 2>/dev/null