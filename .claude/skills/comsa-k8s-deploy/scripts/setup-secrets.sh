#!/bin/bash
# Create Kubernetes secrets for database credentials

set -e

echo "=== Creating Database Secrets ==="

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    echo "Please create .env file with database credentials"
    exit 1
fi

# Load environment variables
source .env

# Create secret
kubectl create secret generic comsa-db-credentials \
    --from-literal=PGHOST="${PGHOST}" \
    --from-literal=PGPORT="${PGPORT}" \
    --from-literal=PGUSER="${PGUSER}" \
    --from-literal=PGPASSWORD="${PGPASSWORD}" \
    --from-literal=PGDATABASE="${PGDATABASE}" \
    --namespace=comsa-dashboard \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Database secrets created/updated successfully"
