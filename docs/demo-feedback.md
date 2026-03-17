# COMSA Dashboard -- Demo Review Feedback

## Introduction Videos -- Methodology Detail

| Timestamp | Issue |
|-----------|-------|
| 0:30 | Mispronounces InterVA and EAVA |
| 0:50 | Can we include a real map of the 7 countries? |
| 9:45 | InterVA, EAVA mispronounced |

## General Feedback on Demos

- **Sort CSMF by descending value** -- Lots of causes with zeros are of less interest and should appear at the bottom
- **Runtime allocations don't match** -- e.g., pipeline analyses show inconsistent times
- **Show analysis name while running** -- e.g., "Neonate -- InterVA Mozambique (openVA)" instead of "Job: bcc9e8ae-5d69-..." -- especially important when users run multiple jobs at once
- **Remove "quick" and "accurate" tags** -- Not sure these are needed in Demos

## Demo Test Results

### Neonate Demos

| Demo | Status | Notes |
|------|--------|-------|
| InterVA -- Mozambique (openVA) | Pass | |
| InSilicoVA -- Mozambique (openVA) | Bug | No causes listed (only numbers) |
| EAVA -- Mozambique (openVA) | Error | `install.packages('EAVA')` needed |
| InterVA -- Ethiopia (Pipeline) | Not tested | |
| InterVA -- Mozambique (Pipeline, Fixed Model) | Not tested | |
| InSilicoVA -- Mozambique (Calibration) | Pass | |
| Ensemble -- South Africa (Calibration) | Pass | |
| InterVA -- Sierra Leone (Calibration) | Pass | |
| InterVA -- Other Country (openVA) | Pass | |

### Child Demos

| Demo | Status | Notes |
|------|--------|-------|
| All child demos | Failing | Not running to completion |
| InterVA -- Bangladesh (Pipeline) | Not tested | |
| InterVA -- Other Country (openVA) | Bug | "Running" status but no output |
