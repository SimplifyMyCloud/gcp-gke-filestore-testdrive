#!/bin/bash

# Script to manually create PVCs if Terraform times out

PROJECT_ID="simplifymycloud-dev"

echo "Creating PVCs for both clusters..."

# Cluster 1 PVC
echo "Setting up Cluster 1 PVC..."
gcloud container clusters get-credentials filestore-cluster-1 \
  --zone us-west1-a \
  --project $PROJECT_ID

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: enterprise-filestore-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Gi
  storageClassName: ""
  volumeName: enterprise-filestore-pv-main-c1
EOF

echo "Cluster 1 PVC status:"
kubectl get pvc enterprise-filestore-pvc

# Cluster 2 PVC
echo -e "\nSetting up Cluster 2 PVC..."
gcloud container clusters get-credentials filestore-cluster-2 \
  --zone us-west1-b \
  --project $PROJECT_ID

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: enterprise-filestore-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Gi
  storageClassName: ""
  volumeName: enterprise-filestore-pv-main-c2
EOF

echo "Cluster 2 PVC status:"
kubectl get pvc enterprise-filestore-pvc

echo -e "\nPVC creation complete. Checking status across both clusters..."

# Check status
echo -e "\n=== Cluster 1 PVCs ==="
gcloud container clusters get-credentials filestore-cluster-1 --zone us-west1-a --project $PROJECT_ID
kubectl get pvc

echo -e "\n=== Cluster 2 PVCs ==="
gcloud container clusters get-credentials filestore-cluster-2 --zone us-west1-b --project $PROJECT_ID
kubectl get pvc