# JHU IDIES k8s-dev Cluster Information

## Cluster Details

**Cluster Name:** k8s-dev
**API Server:** `https://k8sdev.idies.jhu.edu:6443`
**Public URL:** `dev.sites.idies.jhu.edu`
**Your Namespace:** `comsa-dashboard`
**Your App URL:** `https://dev.sites.idies.jhu.edu/comsa-dashboard`

## Access

### SSH Access

```bash
# From your local machine
ssh cliu238@dslogin01.pha.jhu.edu

# From dslogin01, access k8s login node
ssh -p 14132 k8slgn.idies.jhu.edu
```

### Kubeconfig

**Location:** `/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf`

**Usage:**
```bash
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
kubectl get pods -n comsa-dashboard
```

## Permissions

You have **admin** permissions in the `comsa-dashboard` namespace:
- Full CRUD on pods, deployments, services, configmaps, secrets
- Can exec into pods, port-forward, view logs
- Cannot access cluster-level resources or other namespaces

## URL Structure

The cluster exposes applications via path-based routing:

**Pattern:** `dev.sites.idies.jhu.edu/<project-name>`

**Your URLs:**
- Frontend: `https://dev.sites.idies.jhu.edu/comsa-dashboard`
- Backend API: `https://dev.sites.idies.jhu.edu/comsa-dashboard/api`

## Ingress Configuration

The cluster uses **nginx-ingress-controller**. Key annotations:

```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /$2
  nginx.ingress.kubernetes.io/use-regex: "true"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

**Path format:** `/comsa-dashboard(/|$)(.*)`
- This strips `/comsa-dashboard` prefix and forwards remaining path to service

## Network Access

### Database Connection

PostgreSQL server at `172.23.53.49:5432` is directly accessible from k8s pods.

**Connection from pods:**
```bash
# Environment variables from secrets
PGHOST=172.23.53.49
PGPORT=5432
PGUSER=eric
PGPASSWORD=<from-secret>
PGDATABASE=comsa_dashboard
```

### Internet Access

Pods have outbound internet access for:
- Downloading R packages
- npm/pip package installation during image builds
- External API calls

## Resource Limits

**Per Namespace:**
- CPU: Check with cluster admin
- Memory: Check with cluster admin
- Storage: Check with cluster admin

**Recommended per pod:**
- Backend: 512Mi-2Gi memory, 250m-1000m CPU
- Frontend: 128Mi-256Mi memory, 100m-200m CPU

## Container Registry

**GitHub Container Registry (ghcr.io)** is used for images:
- `ghcr.io/cliu238/comsa-dashboard-backend:latest`
- `ghcr.io/cliu238/comsa-dashboard-frontend:latest`

Images are automatically built and pushed by GitHub Actions.

## Common Commands

### View deployments
```bash
kubectl get deployments -n comsa-dashboard
kubectl get pods -n comsa-dashboard
kubectl get svc -n comsa-dashboard
kubectl get ingress -n comsa-dashboard
```

### View logs
```bash
kubectl logs -f deployment/comsa-backend -n comsa-dashboard
kubectl logs -f deployment/comsa-frontend -n comsa-dashboard
```

### Restart deployment
```bash
kubectl rollout restart deployment/comsa-backend -n comsa-dashboard
kubectl rollout restart deployment/comsa-frontend -n comsa-dashboard
```

### Exec into pod
```bash
kubectl exec -it deployment/comsa-backend -n comsa-dashboard -- bash
```

### Port forward (for local testing)
```bash
kubectl port-forward deployment/comsa-backend 8000:8000 -n comsa-dashboard
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name> -n comsa-dashboard
kubectl logs <pod-name> -n comsa-dashboard
```

### Database connection issues
```bash
# Test from pod
kubectl exec -it deployment/comsa-backend -n comsa-dashboard -- \
  psql -h 172.23.53.49 -U eric -d comsa_dashboard
```

### Ingress not working
```bash
kubectl describe ingress comsa-dashboard -n comsa-dashboard
kubectl get ingress -n comsa-dashboard -o yaml
```

## Support

For cluster issues, contact: JHU IDIES k8s-dev cluster administrators
