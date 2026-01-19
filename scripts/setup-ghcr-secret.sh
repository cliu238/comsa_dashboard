#!/bin/bash
# Setup GitHub Container Registry pull secret
set -e

echo "=== Setting up GitHub Container Registry Secret ==="

# Check if gh CLI is authenticated (local machine only)
if command -v gh &> /dev/null; then
    if ! gh auth status &>/dev/null; then
        echo "Error: gh CLI not authenticated. Run 'gh auth login' first."
        exit 1
    fi

    GH_TOKEN=$(gh auth token)
    GH_USERNAME=$(gh api user --jq .login)
else
    echo "Note: gh CLI not found. Using manual credentials."
    read -p "GitHub username: " GH_USERNAME
    read -sp "GitHub personal access token (with read:packages scope): " GH_TOKEN
    echo
fi

# Set kubeconfig
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf

echo "Creating secret for user: $GH_USERNAME"

# Delete existing secret if it exists (to update)
kubectl delete secret ghcr-secret -n comsa-dashboard --ignore-not-found

# Create new secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username="$GH_USERNAME" \
  --docker-password="$GH_TOKEN" \
  --docker-email="${GH_USERNAME}@users.noreply.github.com" \
  --namespace=comsa-dashboard

echo "✅ Secret created successfully"
kubectl get secret ghcr-secret -n comsa-dashboard
