# VA Calibration Platform

Web platform for processing verbal autopsy (VA) data and calibrating cause-of-death classifications using openVA and vacalibration R packages.

## Prerequisites

- **R** (>= 4.0) with packages:
  - plumber
  - jsonlite
  - uuid
  - future
  - openVA
  - vacalibration

- **Node.js** (>= 18)

## Installation

### Backend (R)

```bash
# Install R packages
Rscript -e "install.packages(c('plumber', 'jsonlite', 'uuid', 'future'))"

# openVA and vacalibration should already be installed
```

### Frontend (React)

```bash
cd frontend
npm install
```

## Starting the Application

### 1. Start Backend Server

```bash
cd backend
Rscript run.R
```

The API will be available at `http://localhost:8000`

### 2. Start Frontend Dev Server

In a new terminal:

```bash
cd frontend
npm run dev
```

The web app will be available at `http://localhost:5173`

## Frontend-Backend Connection

The frontend connects to the backend API via the API client (`frontend/src/api/client.js`). The connection is configured differently for local development versus deployed environments.

### Local Development Mode

When running `npm run dev`:
- Frontend runs on `http://localhost:5173` (Vite dev server)
- Backend must be running on `http://localhost:8000` (R plumber API)
- API client defaults to `http://localhost:8000` (no environment file needed)
- Direct connection from frontend to backend

**Important:** Ensure the backend server is running first before starting the frontend dev server.

### Deployed/Production Mode

When deployed to Kubernetes:
- Build process uses `.env.production` with `VITE_API_BASE_URL=/comsa-dashboard/api`
- API base URL is baked into the bundle at build time
- Frontend nginx server proxies `/api/*` requests to backend service
- Browser makes requests to relative URLs like `/comsa-dashboard/api/health`

### Configuration Summary

| Mode       | Frontend URL              | Backend URL           | API Base URL            |
|------------|---------------------------|-----------------------|-------------------------|
| Local Dev  | http://localhost:5173     | http://localhost:8000 | http://localhost:8000   |
| Deployed   | /comsa-dashboard          | comsa-backend:8000    | /comsa-dashboard/api    |

## Usage

1. Open `http://localhost:5173` in your browser
2. Select job options:
   - **Job Type**: Full Pipeline (openVA + Calibration), openVA only, or Calibration only
   - **Algorithm**: InterVA (faster) or InSilicoVA (more accurate)
   - **Age Group**: Neonate (0-27 days) or Child (1-59 months)
   - **Country**: Mozambique (default)
3. Upload a CSV file or click **Run Demo** to use sample data
4. Monitor job progress in the Status and Log tabs
5. View results with CSMF comparison table and chart
6. Download output files (causes.csv, calibration_summary.csv)

## Data Requirements

### Sample Data Files

Sample files are available in `frontend/public/`:

- **openVA samples** (WHO2016 format):
  - `sample_openva_neonate.csv` - Neonate deaths (0-27 days)
  - `sample_openva_child.csv` - Child deaths (1-59 months)
  - Use with job type: **openVA** (coding only) or **Pipeline** (coding + calibration)

- **vacalibration samples** (ID + cause format):
  - `sample_vacalibration_neonate.csv` - Pre-coded neonate causes
  - `sample_vacalibration_child.csv` - Pre-coded child causes
  - Use with job type: **Calibration** (calibration only)

**To demonstrate misclassification matrices:** Upload an openVA sample and select **Pipeline** job type. The results will show cause assignments, CSMFs, calibration, and misclassification matrices with both table and heatmap views.

### Input Data Formats

#### openVA Jobs (InterVA, InSilicoVA)

**Format:** WHO2016 CSV with 354 columns

**Required columns:**
- `ID` - Unique identifier for each death
- WHO2016 symptom indicators (e.g., `i004a`, `i019a`, `i022a`, ...)
- Values: `y` (yes), `n` (no), `.` (don't know/missing)

**Example:**
```csv
ID,i004a,i004b,i019a,i019b,...
d1,n,y,y,n,...
d2,y,n,n,y,...
```

#### openVA Jobs (EAVA)

**Format:** WHO2016 CSV OR EAVA-specific format

**Required columns:**
- All WHO2016 columns (as above)
- `age` - Age at death in days (numeric)
- `fb_day0` - Death on first day of life (`y` or `n`)

**Note:** If uploading WHO2016 data without `age` and `fb_day0` columns, the platform automatically adds default values:
- Neonate: `age = 14` days, `fb_day0 = "n"`
- Child: `age = 180` days, `fb_day0 = "n"`

#### Vacalibration Jobs

**Format:** CSV with ID and cause columns

**Required columns:**
- `ID` - Unique identifier (must match IDs from openVA output)
- `cause` - WHO cause name (e.g., "Birth asphyxia", "Neonatal sepsis", "Pneumonia")

**Important:** Causes must match the selected age group. The platform maps WHO cause names to broad categories:
- **Neonate (6 categories):** congenital_malformation, pneumonia, sepsis_meningitis_inf, ipre, other, prematurity
- **Child (9 categories):** malaria, pneumonia, diarrhea, severe_malnutrition, hiv, injury, other, other_infections, nn_causes

**Example:**
```csv
ID,cause
10004,Birth asphyxia
10006,Neonatal sepsis
10008,Prematurity
```

### Misclassification Matrices

Misclassification matrices appear in results when running:
- **Pipeline jobs** (openVA → vacalibration)
- **Calibration-only jobs** (vacalibration)

The matrices show:
- **Rows:** CHAMPS causes (gold standard)
- **Columns:** VA algorithm predicted causes
- **Values:** Probabilities of misclassification
- **Views:** Table (exact probabilities) and Heatmap (color gradient)
- **Ensemble jobs:** Show separate matrix for each algorithm

These matrices are pre-computed from CHAMPS validation data and used to calibrate cause-specific mortality fractions (CSMFs).

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /health | Health check |
| POST | /jobs | Submit new job |
| POST | /jobs/demo | Run demo with sample data |
| GET | /jobs | List all jobs |
| GET | /jobs/{id}/status | Get job status |
| GET | /jobs/{id}/log | Get job log |
| GET | /jobs/{id}/results | Get job results |
| GET | /jobs/{id}/download/{file} | Download output file |

## Deployment

The application is deployed to **JHU IDIES k8s-dev cluster** with automated CI/CD via GitHub Actions.

**Live URL:** https://dev.sites.idies.jhu.edu/comsa-dashboard

### Automatic Deployment (Recommended)

Push code changes to master branch to trigger automatic deployment:

```bash
git add .
git commit -m "Your changes"
git push origin master
```

GitHub Actions will:
1. Build Docker images for backend and frontend
2. Push images to GitHub Container Registry (ghcr.io)
3. Deploy to Kubernetes cluster
4. Rolling update with zero downtime

**Monitor deployment:**
- GitHub Actions: https://github.com/cliu238/comsa_dashboard/actions
- Or SSH to cluster and watch pods:

```bash
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
watch kubectl get pods -n comsa-dashboard
```

### Manual Redeployment Options

**Option 1: Restart pods without rebuilding**
```bash
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf

# Restart deployments
kubectl rollout restart deployment/comsa-backend -n comsa-dashboard
kubectl rollout restart deployment/comsa-frontend -n comsa-dashboard

# Watch rollout status
kubectl rollout status deployment/comsa-backend -n comsa-dashboard
kubectl rollout status deployment/comsa-frontend -n comsa-dashboard
```

**Option 2: Build and deploy manually**
```bash
# Build and push images
scripts/build-images.sh

# Deploy to cluster
ssh cliu238@dslogin01.pha.jhu.edu
ssh -p 14132 k8slgn.idies.jhu.edu
export KUBECONFIG=/var/k8s/users/cliu238/k8s-dev-comsa-dashboard-admins.conf
scripts/deploy.sh
```

### Verify Deployment

```bash
# Check pod status
kubectl get pods -n comsa-dashboard

# Check logs
kubectl logs -f deployment/comsa-backend -n comsa-dashboard
kubectl logs -f deployment/comsa-frontend -n comsa-dashboard

# Test endpoints
curl https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health
```

### Deployment Architecture

- **Frontend:** React app served by nginx on port 8080
  - Nginx proxies `/api/*` requests to backend service at `http://comsa-backend:8000`
  - API base URL is set to `/comsa-dashboard/api` during build (from `.env.production`)
- **Backend:** R Plumber API on port 8000
- **Database:** PostgreSQL (external at 172.23.53.49:5432)
- **Container Registry:** GitHub Container Registry (ghcr.io)
- **Image Pull Secret:** `ghcr-secret` for private registry authentication

## Project Structure

```
comsa_dashboard/
├── backend/
│   ├── plumber.R          # API endpoints
│   ├── run.R              # Server startup
│   ├── Dockerfile         # Backend container image
│   ├── jobs/
│   │   └── processor.R    # Job processing logic
│   └── data/
│       ├── jobs/          # Job JSON files
│       ├── uploads/       # Uploaded files
│       └── outputs/       # Result files
├── frontend/
│   ├── src/
│   │   ├── api/
│   │   │   └── client.js  # API client
│   │   ├── components/
│   │   │   ├── JobForm.jsx
│   │   │   ├── JobList.jsx
│   │   │   └── JobDetail.jsx
│   │   ├── App.jsx
│   │   └── App.css
│   ├── Dockerfile         # Frontend container image
│   ├── vite.config.js     # Vite build config
│   └── package.json
├── k8s/                   # Kubernetes manifests
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── ingress.yaml
│   └── secrets.yaml
├── scripts/               # Deployment scripts
│   ├── build-images.sh
│   ├── deploy.sh
│   ├── setup-secrets.sh
│   └── setup-ghcr-secret.sh
├── .github/workflows/     # CI/CD pipeline
│   └── deploy.yml
└── README.md
```
