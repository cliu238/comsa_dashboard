#!/bin/bash
# Build and push Docker images to GitHub Container Registry

set -e

echo "=== Building and Pushing Docker Images ==="

# Check if logged into ghcr.io
if ! docker info 2>/dev/null | grep -q "Username"; then
    echo "Please log in to GitHub Container Registry:"
    echo "  docker login ghcr.io -u cliu238"
    exit 1
fi

# Build backend image
echo "Building backend image..."
docker build -t ghcr.io/cliu238/comsa-dashboard-backend:latest \
    -f backend/Dockerfile .

echo "Pushing backend image..."
docker push ghcr.io/cliu238/comsa-dashboard-backend:latest

echo "✅ Backend image pushed"
echo ""

# Build frontend image
echo "Building frontend image..."
docker build -t ghcr.io/cliu238/comsa-dashboard-frontend:latest \
    -f frontend/Dockerfile .

echo "Pushing frontend image..."
docker push ghcr.io/cliu238/comsa-dashboard-frontend:latest

echo "✅ Frontend image pushed"
echo ""

echo "✅ All images built and pushed successfully!"
echo ""
echo "Backend image: ghcr.io/cliu238/comsa-dashboard-backend:latest"
echo "Frontend image: ghcr.io/cliu238/comsa-dashboard-frontend:latest"
