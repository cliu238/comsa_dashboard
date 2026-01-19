# COMSA Dashboard Deployment Guide

## Overview

This guide covers deploying the COMSA Dashboard application to the JHU IDIES k8s-dev cluster.

**Application components:**
- React frontend (served via nginx)
- R Plumber backend API
- PostgreSQL database (external, pre-existing at 172.23.53.49)

**Deployment methods:**
1. Automated CI/CD (GitHub Actions) - **Recommended**
2. Manual deployment (kubectl)

## Prerequisites

- Access to k8s-dev cluster (see `k8s-cluster-info.md`)
- Database credentials in `.env` file
- Docker images built and pushed to ghcr.io
- GitHub repository secrets configured (for CI/CD)

## Method 1: Automated CI/CD Deployment (Recommended)

### Initial Setup

**1. Copy Dockerfiles to project root**

```bash
cp .claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend backend/Dockerfile
cp .claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.frontend frontend/Dockerfile
```

**2. Copy Kubernetes manifests**

```bash
mkdir -p k8s
cp .claude/skills/comsa-k8s-deploy/assets/k8s/*.yaml k8s/
```

**3. Copy GitHub Actions workflow**

```bash
mkdir -p .github/workflows
cp .claude/skills/comsa-k8s-deploy/assets/.github/workflows/deploy.yml .github/workflows/
```

**4. Configure GitHub Secrets**

Go to GitHub repository → Settings → Secrets and variables → Actions

Add secret:
- Name: `K8S_SSH_PASSWORD`
- Value: Your SSH password (Baza7183!)

**5. Make repository package public (for images)**

Go to GitHub repository → Packages
- Find `comsa-dashboard-backend` and `comsa-dashboard-frontend`
- Change visibility to Public (or configure image pull secrets)

**6. Create database secrets on cluster**

```bash
# SSH to k8s login node
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu

# Set kubeconfig
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf

# Create secret
kubectl create secret generic comsa-db-credentials \
  --from-literal=PGHOST=172.23.53.49 \
  --from-literal=PGPORT=5432 \
  --from-literal=PGUSER=eric \
  --from-literal=PGPASSWORD=ChangeMeNow1234 \
  --from-literal=PGDATABASE=comsa_dashboard \
  --namespace=comsa-dashboard
```

**7. Push to master branch**

```bash
git add k8s/ backend/Dockerfile frontend/Dockerfile .github/workflows/deploy.yml
git commit -m "Add Kubernetes deployment and CI/CD"
git push origin master
```

GitHub Actions will automatically:
1. Build Docker images
2. Push to ghcr.io
3. Deploy to k8s-dev cluster
4. Wait for rollout to complete

**8. Monitor deployment**

Go to GitHub → Actions tab to watch progress.

**9. Access application**

Once deployed:
- Frontend: https://dev.sites.idies.jhu.edu/comsa-dashboard
- Backend API: https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health

## Method 2: Manual Deployment

### Step 1: Build and Push Images

```bash
# Log in to GitHub Container Registry
docker login ghcr.io -u cliu238

# Run build script
.claude/skills/comsa-k8s-deploy/scripts/build-images.sh
```

### Step 2: Create Database Secrets

```bash
# SSH to k8s login node
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu

# Copy project files
git clone https://github.com/cliu238/comsa_dashboard.git
cd comsa_dashboard

# Create .env file
cat > .env << EOF
PGHOST=172.23.53.49
PGPORT=5432
PGUSER=eric
PGPASSWORD=ChangeMeNow1234
PGDATABASE=comsa_dashboard
EOF

# Run setup script
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
.claude/skills/comsa-k8s-deploy/scripts/setup-secrets.sh
```

### Step 3: Deploy to Kubernetes

```bash
# Still on k8s login node
.claude/skills/comsa-k8s-deploy/scripts/deploy.sh
```

The script will:
1. Verify cluster access
2. Apply all manifests
3. Wait for deployments to be ready
4. Show deployment status

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n comsa-dashboard

# Check services
kubectl get svc -n comsa-dashboard

# Check ingress
kubectl get ingress -n comsa-dashboard

# View backend logs
kubectl logs -f deployment/comsa-backend -n comsa-dashboard

# View frontend logs
kubectl logs -f deployment/comsa-frontend -n comsa-dashboard
```

## Updating Deployment

### Via CI/CD

Simply push changes to master branch. GitHub Actions will rebuild and redeploy automatically.

### Manual Update

```bash
# Rebuild images
.claude/skills/comsa-k8s-deploy/scripts/build-images.sh

# Restart deployments to pull new images
kubectl rollout restart deployment/comsa-backend -n comsa-dashboard
kubectl rollout restart deployment/comsa-frontend -n comsa-dashboard

# Watch rollout
kubectl rollout status deployment/comsa-backend -n comsa-dashboard
kubectl rollout status deployment/comsa-frontend -n comsa-dashboard
```

## Rollback

### Rollback to previous version

```bash
kubectl rollout undo deployment/comsa-backend -n comsa-dashboard
kubectl rollout undo deployment/comsa-frontend -n comsa-dashboard
```

### Rollback to specific revision

```bash
# View history
kubectl rollout history deployment/comsa-backend -n comsa-dashboard

# Rollback to specific revision
kubectl rollout undo deployment/comsa-backend -n comsa-dashboard --to-revision=2
```

## Monitoring

### View logs in real-time

```bash
kubectl logs -f deployment/comsa-backend -n comsa-dashboard
kubectl logs -f deployment/comsa-frontend -n comsa-dashboard
```

### View pod status

```bash
kubectl get pods -n comsa-dashboard -w
```

### Describe pod (for troubleshooting)

```bash
kubectl describe pod <pod-name> -n comsa-dashboard
```

## Testing

### Test backend API

```bash
curl https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health
```

### Test database connection from pod

```bash
kubectl exec -it deployment/comsa-backend -n comsa-dashboard -- \
  Rscript -e "library(RPostgres); con <- dbConnect(Postgres(), host=Sys.getenv('PGHOST'), port=as.integer(Sys.getenv('PGPORT')), user=Sys.getenv('PGUSER'), password=Sys.getenv('PGPASSWORD'), dbname=Sys.getenv('PGDATABASE')); print(dbGetQuery(con, 'SELECT version()')); dbDisconnect(con)"
```

## Troubleshooting

### Pods in CrashLoopBackOff

```bash
# View pod logs
kubectl logs <pod-name> -n comsa-dashboard

# Describe pod for events
kubectl describe pod <pod-name> -n comsa-dashboard
```

### Image pull errors

```bash
# Check if images exist
docker pull ghcr.io/cliu238/comsa-dashboard-backend:latest

# Check if images are public or create imagePullSecrets
```

### Database connection errors

```bash
# Test from pod
kubectl exec -it deployment/comsa-backend -n comsa-dashboard -- bash
# Then inside pod:
psql -h $PGHOST -U $PGUSER -d $PGDATABASE
```

### Ingress not routing correctly

```bash
# Check ingress
kubectl describe ingress comsa-dashboard -n comsa-dashboard

# Check if services are running
kubectl get svc -n comsa-dashboard

# Test service directly (port-forward)
kubectl port-forward svc/comsa-backend 8000:8000 -n comsa-dashboard
curl http://localhost:8000/health
```

### GitHub Actions workflow failures

**Symptom:** Deployment step fails with shell syntax errors or unexpected token errors

**Cause:** Complex nested heredocs with variable interpolation can fail across SSH tunnels

**Solution:** The workflow clones the repository on the k8s cluster and applies manifests from there:
- Ensures manifest files match the committed version
- Avoids shell escaping issues with nested heredocs
- Simplifies command structure

**Manual verification:**
```bash
# SSH to k8s cluster
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu

# Check if repo exists and is up to date
cd ~/comsa_dashboard
git status
git pull
```

### GitHub Secrets corrupting SSH private keys

**Symptom:** `Error loading key: error in libcrypto` when using SSH key from GitHub Secret

**Cause:** GitHub Secrets doesn't preserve newlines in multi-line content, corrupting OpenSSH private key format

**Solution:** Store SSH key as single-line base64 in GitHub Secret:

1. Encode the private key:
   ```bash
   base64 -i ~/.ssh/your_key | tr -d '\n'
   ```

2. Store the output in GitHub Secret (e.g., `K8S_SSH_PRIVATE_KEY`)

3. Decode in workflow:
   ```bash
   echo "${{ secrets.K8S_SSH_PRIVATE_KEY }}" | base64 -d > ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   ```

**Why this works:** Base64 creates a single line, bypassing GitHub's newline handling issues.

### SSH agent not available in deploy step

**Symptom:** `Permission denied (publickey)` in deploy step despite SSH key being added in previous step

**Cause:** Each GitHub Actions step runs in a fresh shell; ssh-agent from previous step doesn't persist

**Solution:** Save SSH agent socket to GitHub environment:

```yaml
- name: Setup SSH key
  run: |
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa

    # Persist agent for subsequent steps
    echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> $GITHUB_ENV
    echo "SSH_AGENT_PID=$SSH_AGENT_PID" >> $GITHUB_ENV

- name: Deploy
  env:
    SSH_AUTH_SOCK: ${{ env.SSH_AUTH_SOCK }}
  run: |
    ssh -A user@host ...
```

**Why this works:** GITHUB_ENV persists environment variables across workflow steps.

### Docker builds taking too long

**Symptom:** Docker builds take 10-12 minutes on every run

**Causes:**
1. No layer caching - builds from scratch every time
2. Building on every commit, even for documentation changes

**Solutions:**

1. **Enable Docker layer caching:**
   ```yaml
   - name: Set up Docker Buildx
     uses: docker/setup-buildx-action@v3

   - name: Build and push
     uses: docker/build-push-action@v5
     with:
       cache-from: type=gha
       cache-to: type=gha,mode=max
   ```

2. **Add path filters to skip unnecessary builds:**
   ```yaml
   jobs:
     check-changes:
       runs-on: ubuntu-latest
       outputs:
         backend: ${{ steps.filter.outputs.backend }}
       steps:
       - uses: dorny/paths-filter@v3
         id: filter
         with:
           filters: |
             backend:
               - 'backend/**'
               - 'k8s/backend-deployment.yaml'

     build:
       needs: check-changes
       if: needs.check-changes.outputs.backend == 'true'
   ```

**Impact:** First build with cache: ~12min (creates cache). Subsequent builds: 30s-2min. Documentation-only changes: 12-14s.

### SSH agent forwarding not working through jump host

**Symptom:** First SSH succeeds, but nested SSH to k8s cluster fails with "Permission denied"

**Cause:** Nested heredocs don't properly forward SSH agent

**Solution:** Use single-line nested SSH command instead of nested heredocs:

**Bad (nested heredocs):**
```bash
ssh -A user@jumphost << 'OUTER_EOF'
ssh -p 14132 user@k8s << 'INNER_EOF'
kubectl apply -f manifest.yaml
INNER_EOF
OUTER_EOF
```

**Good (single-line nested):**
```bash
ssh -A user@jumphost 'ssh -A -p 14132 user@k8s bash -s' << 'EOF'
kubectl apply -f manifest.yaml
EOF
```

**Why this works:** Agent forwarding works correctly with the simplified structure.

### Ingress validation error with regex paths

**Symptom:** `admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: ingress contains invalid paths: path /app(/|$)(.*) cannot be used with pathType Prefix`

**Cause:** nginx ingress controller doesn't accept regex patterns with `pathType: Prefix`

**Solution:** Use `pathType: ImplementationSpecific` for regex patterns:

```yaml
- path: /app(/|$)(.*)
  pathType: ImplementationSpecific  # Required for regex
```

**Why this works:** ImplementationSpecific allows nginx-specific path matching including regex.

## Clean Up

### Delete deployment

```bash
kubectl delete deployment comsa-backend comsa-frontend -n comsa-dashboard
kubectl delete svc comsa-backend comsa-frontend -n comsa-dashboard
kubectl delete ingress comsa-dashboard -n comsa-dashboard
kubectl delete secret comsa-db-credentials -n comsa-dashboard
```

Note: The namespace itself cannot be deleted (managed by cluster admin).
