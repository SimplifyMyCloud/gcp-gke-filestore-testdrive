#!/bin/bash

set -e

echo "================================================"
echo "GKE + Filestore Demo Environment Deployment"
echo "================================================"

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "terraform is required but not installed. Aborting." >&2; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "gcloud is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }

# Get project ID
if [ -z "$1" ]; then
    echo "Usage: ./deploy.sh <project-id>"
    exit 1
fi

PROJECT_ID=$1
REGION=${2:-us-central1}
ZONE=${3:-us-central1-a}

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Zone: $ZONE"
echo ""

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable compute.googleapis.com --project=$PROJECT_ID
gcloud services enable container.googleapis.com --project=$PROJECT_ID
gcloud services enable file.googleapis.com --project=$PROJECT_ID
gcloud services enable servicenetworking.googleapis.com --project=$PROJECT_ID

# Deploy Terraform
echo ""
echo "Initializing Terraform..."
terraform init

echo ""
echo "Creating terraform.tfvars..."
cat > terraform.tfvars <<EOF
project_id = "$PROJECT_ID"
region     = "$REGION"
zone       = "$ZONE"
EOF

echo ""
echo "Planning Terraform deployment..."
terraform plan

echo ""
echo "Do you want to proceed with the deployment? (yes/no)"
read -r response
if [[ "$response" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Configure kubectl:"
echo "gcloud container clusters get-credentials filestore-demo-cluster --region $REGION --project $PROJECT_ID"
echo ""
echo "View outputs:"
echo "terraform output"