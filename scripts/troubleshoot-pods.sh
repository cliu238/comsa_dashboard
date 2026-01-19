#!/bin/bash
# Troubleshoot pod startup issues on k8s cluster
# Run this on the k8s login node after setting KUBECONFIG

set -e

echo "=== Troubleshooting COMSA Dashboard Pods ==="
echo ""

# Set kubeconfig
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf

echo "1. Checking pod status..."
kubectl get pods -n comsa-dashboard
echo ""

echo "2. Checking deployment status..."
kubectl get deployments -n comsa-dashboard
echo ""

echo "3. Getting detailed pod information..."
for pod in $(kubectl get pods -n comsa-dashboard -o name); do
    echo "--- Details for $pod ---"
    kubectl describe $pod -n comsa-dashboard | tail -50
    echo ""
done

echo "4. Getting pod logs..."
echo "=== Backend logs ==="
kubectl logs -n comsa-dashboard deployment/comsa-backend --tail=50 || echo "Backend logs not available"
echo ""

echo "=== Frontend logs ==="
kubectl logs -n comsa-dashboard deployment/comsa-frontend --tail=50 || echo "Frontend logs not available"
echo ""

echo "5. Checking secrets..."
kubectl get secrets -n comsa-dashboard
echo ""

echo "6. Checking if database secret exists and has correct keys..."
kubectl get secret comsa-db-credentials -n comsa-dashboard -o jsonpath='{.data}' | jq 'keys' || echo "Secret not found or invalid"
echo ""

echo "7. Checking ingress..."
kubectl get ingress -n comsa-dashboard
echo ""

echo "8. Checking services..."
kubectl get svc -n comsa-dashboard
echo ""

echo "=== Troubleshooting complete ==="
echo ""
echo "Common issues to check:"
echo "  - ImagePullBackOff: Docker images may not be accessible or don't exist"
echo "  - CrashLoopBackOff: Container is starting but immediately crashing (check logs)"
echo "  - Pending: Resources unavailable or scheduling issues"
echo "  - CreateContainerConfigError: Secret or ConfigMap missing"
echo ""
echo "To view real-time logs:"
echo "  kubectl logs -f deployment/comsa-backend -n comsa-dashboard"
echo "  kubectl logs -f deployment/comsa-frontend -n comsa-dashboard"
