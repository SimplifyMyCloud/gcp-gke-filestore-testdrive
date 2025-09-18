#!/bin/bash

set -e

echo "================================================"
echo "Filestore Storage Testing Script"
echo "================================================"

# Check if kubectl is configured
kubectl cluster-info > /dev/null 2>&1 || {
    echo "Error: kubectl not configured. Please run:"
    echo "gcloud container clusters get-credentials filestore-demo-cluster --zone us-west1-a --project your-project-id"
    exit 1
}

echo ""
echo "Step 1: Applying PVC for Filestore..."
kubectl apply -f k8s-manifests/static-pv-example.yaml

echo ""
echo "Step 2: Checking PVC status..."
kubectl get pvc filestore-pvc
echo ""

# Wait for PVC to be bound
echo "Waiting for PVC to be bound..."
while [[ $(kubectl get pvc filestore-pvc -o jsonpath='{.status.phase}') != "Bound" ]]; do
    echo -n "."
    sleep 2
done
echo " Bound!"

echo ""
echo "Step 3: Creating test data generation job..."
kubectl apply -f k8s-manifests/storage-test-job.yaml

echo ""
echo "Step 4: Monitoring data generation..."
echo "Waiting for job to start..."
sleep 5

# Monitor job progress
JOB_POD=$(kubectl get pods -l job-name=generate-test-data -o jsonpath='{.items[0].metadata.name}')
echo "Following logs from pod: $JOB_POD"
echo "---"
kubectl logs -f $JOB_POD 2>/dev/null || echo "Job is starting..."

echo ""
echo "Step 5: Checking storage usage..."
# Get reader pod logs to see storage status
sleep 5
kubectl logs storage-reader --tail=20

echo ""
echo "Step 6: Deploy test deployment to verify multi-pod access..."
kubectl apply -f k8s-manifests/test-deployment.yaml

echo ""
echo "================================================"
echo "Test Complete!"
echo "================================================"
echo ""
echo "Useful commands:"
echo "  # Check storage usage from reader pod:"
echo "  kubectl logs storage-reader --tail=20"
echo ""
echo "  # Access the storage interactively:"
echo "  kubectl exec -it storage-reader -- sh"
echo ""
echo "  # List files in storage:"
echo "  kubectl exec storage-reader -- ls -lh /data/"
echo ""
echo "  # Check from deployment pods:"
echo "  kubectl exec deployment/filestore-test-app -- ls -lh /data/"
echo ""
echo "  # Clean up test data:"
echo "  kubectl exec storage-reader -- rm -f /data/testfile-*.dat"