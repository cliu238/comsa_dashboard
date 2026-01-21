---
name: comsa-k8s-deploy
description: Deploy COMSA Dashboard to JHU IDIES k8s-dev cluster with CI/CD. Use this skill when deploying the application to Kubernetes, setting up CI/CD pipelines, or managing deployments on dev.sites.idies.jhu.edu/comsa-dashboard.
---

# COMSA Dashboard Kubernetes Deployment

## Overview

Deploy the COMSA Dashboard (React frontend + R Plumber backend + PostgreSQL) to the JHU IDIES k8s-dev cluster. The application is exposed at `https://dev.sites.idies.jhu.edu/comsa-dashboard` with automated CI/CD via GitHub Actions.

## When to Use This Skill

Use this skill when:
- Deploying COMSA Dashboard to k8s-dev cluster
- Setting up or updating CI/CD pipelines
- Managing Kubernetes deployments, services, or ingress
- Troubleshooting deployment issues
- Updating application configuration or scaling

## Version History

### v1.16 - 2026-01-20
**Updated:** Synced skill assets with production security hardening and pod restart improvements
- **Security Hardening:**
  - Added pod-level security contexts (runAsNonRoot, runAsUser, fsGroup, seccompProfile) to both deployments
  - Added container security contexts (allowPrivilegeEscalation: false, capabilities drop ALL, readOnlyRootFilesystem)
  - Added imagePullSecrets for GitHub Container Registry authentication
  - Added emptyDir volumes for nginx (cache, run, tmp) to support read-only root filesystem
- **Image Pull Configuration:**
  - Added imagePullPolicy: Always to backend deployment (frontend already had it)
  - Ensures latest Docker images are always pulled on deployment
- **Pod Restart Workflow:**
  - Added kubectl rollout restart commands in CI/CD workflow before rollout status
  - Forces pod restarts to pull latest images even when manifest unchanged
  - Prevents stale deployment issues with :latest tags
- **Impact:** Skill assets now match production configuration - security-hardened, reliable deployments
- **Files:** `assets/k8s/backend-deployment.yaml`, `assets/k8s/frontend-deployment.yaml`, `assets/.github/workflows/deploy.yml`

### v1.17 - 2026-01-20
**Fixed:** Nginx ingress caching issue and backend error field handling
- **Critical Issue:** Nginx ingress was caching responses, preventing browser clients from receiving updated code/data
- **Solution:** Added no-cache headers to ingress configuration
- **Impact:** Prevents stale responses from being served; ensures clients always get latest data
- **Files:** `k8s/ingress.yaml` (added configuration-snippet annotation)
- **Backend Fix:** Improved error field handling in plumber.R
  - Modified job status endpoint to completely omit error field for successful jobs (instead of returning empty object)
  - Added jsonlite::unbox() to prevent R vectors from being serialized as JSON arrays
  - Ensures API returns clean responses: `{"status": "completed"}` instead of `{"status": ["completed"], "error": {}}`
- **Files:** `backend/plumber.R` (job status endpoint), `backend/db/connection.R` (error field parsing)
- **Note:** The ingress caching issue caused significant debugging time. Always consider cache headers when troubleshooting unexpected client behavior.

### v1.15 - 2026-01-20
**Fixed:** Frontend API configuration - deployed frontend now connects to deployed backend
- **Issue:** Deployed frontend hardcoded to `localhost:8000`, connecting to local backend instead of deployed backend
- **Root Cause:** Vite environment variable `VITE_API_BASE_URL` not set during build; Docker layer caching prevented rebuilds
- **Solution:** Create `frontend/.env.production` with `VITE_API_BASE_URL=/comsa-dashboard/api` and invalidate cache
- **Impact:** Frontend correctly connects to deployed backend at `/comsa-dashboard/api` instead of `localhost:8000`
- **Files:** `frontend/.env.production` (new), `frontend/src/api/client.js` (cache-busting comment)
- **Attempts:** Tried ENV/ARG in Dockerfile and vite.config.js define - all failed due to Docker cache
- **Working Solution:** `.env.production` file + source code change to invalidate cache

### v1.14 - 2026-01-20
**Fixed:** rJava compilation linker errors - openVA and vacalibration now fully operational
- **Issue:** rJava failed to compile with linker error: `/usr/bin/ld: cannot find -ldeflate`
- **Solution:** Add `libdeflate-dev` to backend Dockerfile system dependencies
- **Impact:** rJava 1.0-14, openVA 1.2.0, and vacalibration 2.0 now install and work correctly
- **Files:** `backend/Dockerfile` (added libdeflate-dev), `backend/jobs/processor.R` (re-enabled library imports)
- **Verification:** All packages verified loading in production container
- **Resolution:** VA processing pipeline is now fully functional

### v1.13 - 2026-01-19
**Fixed:** Backend R package compilation failures
- **Issue:** Multiple R packages failing to install due to missing system dependencies
- **Solution:** Add required system libraries to Dockerfile: libsodium-dev (sodium), zlib1g-dev (httpuv), build tools, Java
- **Impact:** Core R packages install successfully (plumber, jsonlite, uuid, future, RPostgres)
- **Files:** `backend/Dockerfile` (added system dependencies), `backend/jobs/processor.R` (commented out openVA/vacalibration)
- **Note:** rJava issue was subsequently resolved in v1.14

### v1.12 - 2026-01-19
**Fixed:** Frontend assets loading from wrong path causing blank page
- **Issue:** Vite builds assets with default base path `/`, but app deploys at `/comsa-dashboard/`
- **Solution:** Configure `base: '/comsa-dashboard/'` in vite.config.js
- **Impact:** Assets load correctly from subdirectory path, frontend displays properly
- **Files:** `frontend/vite.config.js`, `frontend/package.json` (version bump to trigger rebuild)

### v1.11 - 2026-01-19
**Changed:** Frontend nginx port from 80 to 8080 for non-root user
- **Issue:** nginx running as non-root user (UID 101) cannot bind to privileged port 80
- **Solution:** Configure nginx to listen on port 8080, update deployment and service accordingly
- **Impact:** Frontend container starts successfully with non-root security context
- **Files:** `frontend/Dockerfile` (nginx.conf listen 8080), `k8s/frontend-deployment.yaml` (containerPort 8080, service targetPort 8080, probes port 8080)
- **Details:** Service still exposes port 80 externally, routes to container port 8080

### v1.10 - 2026-01-19
**Fixed:** Image name mismatch causing ImagePullBackOff
- **Issue:** Workflow pushes images as `comsa_dashboard-*` (underscore) but deployments referenced `comsa-dashboard-*` (hyphen)
- **Solution:** Update deployment manifests to use correct image names with underscores
- **Impact:** Images pull successfully after fixing name mismatch
- **Details:** GitHub repository name uses underscore, which is preserved in image naming

### v1.9 - 2026-01-19
**Added:** GitHub Container Registry authentication with imagePullSecrets
- **Issue:** Pods stuck in ImagePullBackOff - k8s cluster cannot pull private images from ghcr.io
- **Solution:** Create docker-registry secret using GitHub CLI token and add imagePullSecrets to deployments
- **Impact:** Kubernetes can authenticate with GHCR and pull private images
- **Setup:** Run `scripts/setup-ghcr-secret.sh` on k8s cluster to create secret
- **Files:** `k8s/backend-deployment.yaml`, `k8s/frontend-deployment.yaml` (added imagePullSecrets), `scripts/setup-ghcr-secret.sh` (new)

### v1.8 - 2026-01-19
**Fixed:** Ingress pathType validation error
- **Issue:** nginx ingress rejects regex patterns with `pathType: Prefix`
- **Solution:** Use `pathType: ImplementationSpecific` for regex path patterns
- **Impact:** Ingress resources apply successfully without validation errors
- **Files:** `k8s/ingress.yaml` lines 18, 26

### v1.7 - 2026-01-16
**Improved:** Simplified nested SSH command structure
- **Issue:** Nested heredocs don't properly forward SSH agent
- **Solution:** Use single-line nested SSH: `ssh -A ... 'ssh -A ... bash -s' << 'EOF'`
- **Impact:** SSH agent forwarding works correctly through jump host
- **Details:** Avoids complex nested heredoc escaping issues

### v1.6 - 2026-01-16
**Fixed:** SSH agent not persisting across workflow steps
- **Issue:** SSH_AUTH_SOCK empty in deploy step, causing "Permission denied"
- **Solution:** Save agent socket to GitHub environment with `echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> $GITHUB_ENV`
- **Impact:** SSH agent accessible in all subsequent workflow steps

### v1.5 - 2026-01-16
**Added:** Path filters to skip unnecessary builds
- **Issue:** Docker images rebuilt on every push, even for documentation-only changes
- **Solution:** Use dorny/paths-filter@v3 to conditionally run builds only when code changes
- **Impact:** Workflow completes in 12-14s for manifest-only changes, 30s-2min for code changes with cache
- **Details:** Monitors backend/ and frontend/ directories only, not k8s manifests

### v1.4 - 2026-01-16
**Fixed:** GitHub Secrets multi-line corruption issue
- **Issue:** SSH private keys stored in GitHub Secrets lose newlines, causing "error in libcrypto"
- **Solution:** Store SSH key as single-line base64, decode in workflow: `echo "$SECRET" | base64 -d > ~/.ssh/id_rsa`
- **Impact:** SSH key authentication works reliably in GitHub Actions
- **Migration:** Encode key with `base64 -i key_file | tr -d '\n'` before adding to secrets

### v1.3 - 2026-01-16
**Improved:** Add Docker layer caching to speed up builds
- **Issue:** Docker images rebuilt from scratch every time, taking 10-12 minutes
- **Solution:** Enable GitHub Actions cache for Docker layers
- **Impact:** Subsequent builds are much faster (30 seconds to 2 minutes instead of 10-12 minutes)
- **Details:** Uses `cache-from: type=gha` and `cache-to: type=gha,mode=max` in build-push-action

### v1.2 - 2026-01-16
**Changed:** SSH authentication method in CI/CD workflow
- **Issue:** sshpass not available on jump host (dslogin01) for nested SSH connections
- **Solution:** Use SSH key authentication with agent forwarding instead of password auth
- **Impact:** More secure, standard approach; no dependency on sshpass
- **Migration:** Replace `K8S_SSH_PASSWORD` secret with `K8S_SSH_PRIVATE_KEY` containing SSH private key

### v1.1 - 2026-01-16
**Fixed:** GitHub Actions workflow deployment syntax
- **Issue:** Nested heredoc syntax caused workflow failures due to shell escaping complexity
- **Solution:** Deploy by cloning repository on k8s cluster and applying manifests from there
- **Impact:** More reliable CI/CD deployments, simpler workflow maintenance

## Deployment Methods

### Automated CI/CD (Recommended)

GitHub Actions automatically builds Docker images and deploys on every push to master branch.

**Quick Setup:**

1. **Copy deployment files to project:**
   ```bash
   # Dockerfiles
   cp assets/dockerfiles/Dockerfile.backend backend/Dockerfile
   cp assets/dockerfiles/Dockerfile.frontend frontend/Dockerfile

   # Kubernetes manifests
   mkdir -p k8s
   cp assets/k8s/*.yaml k8s/
   rm k8s/secrets.yaml.template  # Don't commit template

   # GitHub Actions workflow
   mkdir -p .github/workflows
   cp assets/.github/workflows/deploy.yml .github/workflows/
   ```

2. **Configure GitHub Secrets:**
   - Go to repository Settings → Secrets → Actions
   - Add `K8S_SSH_PRIVATE_KEY` with SSH private key content (entire key including headers)

3. **Create database secrets on cluster:**
   ```bash
   # SSH to k8s login node
   ssh cliu238@dslogin01.pha.jhu.edu
   ssh -p 14132 k8slgn.idies.jhu.edu

   # Run setup script
   export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
   scripts/setup-secrets.sh

   # Setup GitHub Container Registry authentication
   scripts/setup-ghcr-secret.sh
   ```

4. **Push to trigger deployment:**
   ```bash
   git add k8s/ backend/Dockerfile frontend/Dockerfile .github/workflows/
   git commit -m "Add Kubernetes deployment and CI/CD"
   git push origin master
   ```

GitHub Actions will build images, push to ghcr.io, and deploy to k8s.

### Manual Deployment

For testing or one-off deployments:

1. **Build and push images:**
   ```bash
   scripts/build-images.sh
   ```

2. **Deploy to cluster:**
   ```bash
   # SSH to k8s login node
   ssh cliu238@dslogin01.pha.jhu.edu
   ssh -p 14132 k8slgn.idies.jhu.edu

   # Run deployment
   export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
   scripts/deploy.sh
   ```

## Architecture

**Application Components:**
- **Frontend:** React app (nginx:alpine) → Port 8080 (non-root user requirement)
- **Backend:** R Plumber API (rocker/r-ver:4.4) → Port 8000
- **Database:** PostgreSQL (external at 172.23.53.49:5432)

**Kubernetes Resources:**
- Deployments: `comsa-backend`, `comsa-frontend`
- Services: ClusterIP for both backend and frontend
- Ingress: nginx-ingress with path-based routing
- Secrets: `comsa-db-credentials` for database connection

**URL Structure:**
- Frontend: `https://dev.sites.idies.jhu.edu/comsa-dashboard`
- Backend API: `https://dev.sites.idies.jhu.edu/comsa-dashboard/api/*`

## Database Connection

The backend connects directly to PostgreSQL at `172.23.53.49:5432`. Credentials are stored in Kubernetes secrets and injected as environment variables:

```yaml
env:
  - name: PGHOST
    valueFrom:
      secretKeyRef:
        name: comsa-db-credentials
        key: PGHOST
```

No SSH tunnel needed - k8s pods have direct network access.

## Common Operations

### View deployment status
```bash
kubectl get pods -n comsa-dashboard
kubectl get deployments -n comsa-dashboard
kubectl get ingress -n comsa-dashboard
```

### View logs
```bash
kubectl logs -f deployment/comsa-backend -n comsa-dashboard
kubectl logs -f deployment/comsa-frontend -n comsa-dashboard
```

### Restart deployment (force new image pull)
```bash
kubectl rollout restart deployment/comsa-backend -n comsa-dashboard
kubectl rollout restart deployment/comsa-frontend -n comsa-dashboard
```

### Update secrets
```bash
# Edit and run
scripts/setup-secrets.sh

# Restart pods to pick up new secrets
kubectl rollout restart deployment/comsa-backend -n comsa-dashboard
```

### Scale deployment
```bash
kubectl scale deployment comsa-backend --replicas=2 -n comsa-dashboard
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n comsa-dashboard
kubectl logs <pod-name> -n comsa-dashboard
```

### Database connection errors
```bash
# Test from backend pod
kubectl exec -it deployment/comsa-backend -n comsa-dashboard -- \
  psql -h $PGHOST -U $PGUSER -d $PGDATABASE
```

### Application not accessible
```bash
# Check ingress
kubectl describe ingress comsa-dashboard -n comsa-dashboard

# Test backend service directly
kubectl port-forward svc/comsa-backend 8000:8000 -n comsa-dashboard
curl http://localhost:8000/health
```

### Rollback deployment
```bash
kubectl rollout undo deployment/comsa-backend -n comsa-dashboard
kubectl rollout undo deployment/comsa-frontend -n comsa-dashboard
```

## Resources

### Scripts
- `setup-secrets.sh` - Create/update Kubernetes secrets for database
- `deploy.sh` - Deploy application to cluster (run on k8s login node)
- `build-images.sh` - Build and push Docker images to ghcr.io

### References
- `k8s-cluster-info.md` - Cluster details, access, URLs, permissions
- `deployment-guide.md` - Comprehensive deployment guide with step-by-step instructions

### Assets
- `k8s/*.yaml` - Kubernetes manifests (deployments, services, ingress)
- `dockerfiles/` - Dockerfile templates for backend and frontend
- `.github/workflows/deploy.yml` - GitHub Actions CI/CD workflow

## Next Steps After Deployment

1. **Verify application is running:**
   - Visit https://dev.sites.idies.jhu.edu/comsa-dashboard
   - Test backend API: https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health

2. **Monitor logs for errors:**
   ```bash
   kubectl logs -f deployment/comsa-backend -n comsa-dashboard
   ```

3. **Set up monitoring/alerts** (if needed)

4. **Configure autoscaling** (if needed):
   ```bash
   kubectl autoscale deployment comsa-backend \
     --min=1 --max=3 --cpu-percent=80 -n comsa-dashboard
   ```

For detailed information, see `references/deployment-guide.md` and `references/k8s-cluster-info.md`.
