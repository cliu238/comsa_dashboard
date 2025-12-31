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

## Project Structure

```
comsa_dashboard/
├── backend/
│   ├── plumber.R          # API endpoints
│   ├── run.R              # Server startup
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
│   └── package.json
└── README.md
```
