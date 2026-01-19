# Troubleshooting Pod Startup Issues

## Current Situation

The deployment completed successfully in GitHub Actions, but the pods are not starting. The application returns **503 Service Temporarily Unavailable** errors.

## Step 1: Access the K8s Cluster

SSH to the k8s login node:

```bash
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
```

## Step 2: Run Automated Troubleshooting Script

Clone the repository and run the troubleshooting script:

```bash
cd ~
if [ -d "comsa_dashboard" ]; then
  cd comsa_dashboard && git pull
else
  git clone https://github.com/cliu238/comsa_dashboard.git && cd comsa_dashboard
fi

chmod +x scripts/troubleshoot-pods.sh
./scripts/troubleshoot-pods.sh > /tmp/pod-troubleshooting.txt 2>&1
cat /tmp/pod-troubleshooting.txt
```

## Step 3: Identify the Problem

Based on the pod status, identify the issue:

### ImagePullBackOff

**Symptom:** Pods stuck in `ImagePullBackOff` or `ErrImagePull`

**Cause:** Docker images don't exist or aren't accessible

**Solution:**
```bash
# Check if images exist in GitHub Container Registry
# Visit: https://github.com/cliu238/comsa_dashboard/pkgs/container/comsa-dashboard-backend
# Visit: https://github.com/cliu238/comsa_dashboard/pkgs/container/comsa-dashboard-frontend

# Make sure images are public or create imagePullSecret
```

### CrashLoopBackOff

**Symptom:** Pods starting but immediately crashing

**Cause:** Application failing to start (database connection, missing dependencies, etc.)

**Solution:**
```bash
# View backend logs
kubectl logs deployment/comsa-backend -n comsa-dashboard --tail=100

# View frontend logs
kubectl logs deployment/comsa-frontend -n comsa-dashboard --tail=100

# Common fixes:
# - Check database secret exists and has correct values
# - Verify database is accessible from cluster
# - Check for missing environment variables
```

### CreateContainerConfigError

**Symptom:** Pods stuck in `CreateContainerConfigError`

**Cause:** Missing secrets or configmaps

**Solution:**
```bash
# Check if database secret exists
kubectl get secret comsa-db-credentials -n comsa-dashboard

# If missing, create it:
cd ~/comsa_dashboard
./scripts/setup-secrets.sh
```

### Pending

**Symptom:** Pods stuck in `Pending` state

**Cause:** Insufficient resources or scheduling constraints

**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n comsa-dashboard

# Check node resources
kubectl top nodes
```

### PodSecurity Violations

**Symptom:** Warnings about PodSecurity violations in deployment logs

**Cause:** Missing security contexts in deployment manifests

**Solution:** The deployment manifests have been updated with proper security contexts. Apply the latest changes:
```bash
cd ~/comsa_dashboard
git pull
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
```

## Step 4: Common Fixes

### Fix 1: Create Database Secret (if missing)

```bash
cd ~/comsa_dashboard
./scripts/setup-secrets.sh
```

### Fix 2: Restart Deployments

```bash
kubectl rollout restart deployment/comsa-backend -n comsa-dashboard
kubectl rollout restart deployment/comsa-frontend -n comsa-dashboard
```

### Fix 3: Check Database Connectivity

```bash
# Test from backend pod (if running)
kubectl exec -it deployment/comsa-backend -n comsa-dashboard -- \
  Rscript -e "library(RPostgres); con <- dbConnect(Postgres(), host=Sys.getenv('PGHOST'), port=as.integer(Sys.getenv('PGPORT')), user=Sys.getenv('PGUSER'), password=Sys.getenv('PGPASSWORD'), dbname=Sys.getenv('PGDATABASE')); print('Connected!'); dbDisconnect(con)"
```

### Fix 4: Verify Images are Accessible

```bash
# Try pulling the images manually
docker pull ghcr.io/cliu238/comsa-dashboard-backend:latest
docker pull ghcr.io/cliu238/comsa-dashboard-frontend:latest
```

## Step 5: Monitor Deployment Progress

```bash
# Watch pod status
watch kubectl get pods -n comsa-dashboard

# Follow logs in real-time
kubectl logs -f deployment/comsa-backend -n comsa-dashboard
kubectl logs -f deployment/comsa-frontend -n comsa-dashboard
```

## Step 6: Verify Application is Running

Once pods are in `Running` state and ready (1/1):

```bash
# Check pod status
kubectl get pods -n comsa-dashboard

# Test backend health endpoint via port-forward
kubectl port-forward svc/comsa-backend 8000:8000 -n comsa-dashboard &
curl http://localhost:8000/health

# Check via browser
# Frontend: https://dev.sites.idies.jhu.edu/comsa-dashboard
# Backend: https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health
```

## Recent Changes

The following fixes were applied to address PodSecurity violations:

1. **Added Pod-level security contexts:**
   - `runAsNonRoot: true`
   - `seccompProfile.type: RuntimeDefault`

2. **Added Container-level security contexts:**
   - `allowPrivilegeEscalation: false`
   - `capabilities.drop: ["ALL"]`

3. **Backend:** Runs as user 1000
4. **Frontend:** Runs as user 101 (nginx default)

These changes ensure pods meet the k8s cluster's restricted PodSecurity standards.
