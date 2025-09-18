#!/bin/bash

set -e

echo "================================================"
echo "GKE + Filestore Demo Environment Cleanup"
echo "================================================"

if [ ! -f "terraform.tfstate" ]; then
    echo "No Terraform state found. Nothing to clean up."
    exit 0
fi

echo "This will destroy all resources created by this demo."
echo "Do you want to proceed? (yes/no)"
read -r response
if [[ "$response" != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Destroying Terraform resources..."
terraform destroy -auto-approve

echo ""
echo "================================================"
echo "Cleanup Complete!"
echo "================================================"