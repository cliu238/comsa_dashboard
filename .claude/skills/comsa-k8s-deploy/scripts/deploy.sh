#!/bin/bash
# Main deployment script for COMSA Dashboard to k8s-dev cluster

set -e

echo "=== COMSA Dashboard Deployment ==="

# Check if running on k8s login node
if [[ ! -f "/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf" ]]; then
    echo "Error: Not on k8s login node"
    echo "Please run this script on k8slgn.idies.jhu.edu"
    echo ""
    echo "To access: ssh cliu238@dslogin01.pha.jhu.edu"
    echo "Then: ssh -p 14132 k8slgn.idies.jhu.edu"
    exit 1
fi

# Set kubeconfig
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf

# Verify cluster access
echo "Verifying cluster access..."
kubectl get namespace comsa-dashboard || {
    echo "Error: Cannot access comsa-dashboard namespace"
    exit 1
}

echo "✅ Cluster access verified"
echo ""

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."

echo "  - Backend deployment..."
kubectl apply -f k8s/backend-deployment.yaml

echo "  - Frontend deployment..."
kubectl apply -f k8s/frontend-deployment.yaml

echo "  - Ingress configuration..."
kubectl apply -f k8s/ingress.yaml

echo "✅ Manifests applied"
echo ""

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."

echo "  - Backend..."
kubectl rollout status deployment/comsa-backend -n comsa-dashboard --timeout=5m

echo "  - Frontend..."
kubectl rollout status deployment/comsa-frontend -n comsa-dashboard --timeout=5m

echo "✅ Deployments ready"
echo ""

# Show deployment status
echo "=== Deployment Status ==="
kubectl get pods -n comsa-dashboard
echo ""

echo "=== Services ==="
kubectl get svc -n comsa-dashboard
echo ""

echo "=== Ingress ==="
kubectl get ingress -n comsa-dashboard
echo ""

echo "✅ Deployment complete!"
echo ""
echo "🌐 Access your application at:"
echo "   https://dev.sites.idies.jhu.edu/comsa-dashboard"
echo ""
echo "🔧 Backend API health check:"
echo "   https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health"
