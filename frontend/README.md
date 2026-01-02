# VA Calibration Platform - Frontend

React frontend for the Verbal Autopsy Calibration Platform.

## Setup

```bash
npm install
npm run dev
```

Frontend runs at http://localhost:5173

## Features

- Submit VA processing jobs (openVA, vacalibration, or full pipeline)
- Algorithm selection: InterVA (faster) or InSilicoVA (more accurate)
- Age group support: Neonate (0-27 days) or Child (1-59 months)
- Real-time job status and log monitoring
- Results visualization with CSMF tables
- Sample data demo mode

## API

Requires the R plumber backend running at http://localhost:8000

## Tech Stack

- React + Vite
- Fetch API for backend communication
