#!/bin/bash
# Test script for verifying sample data with the platform
# This script provides instructions for manual testing

cat << 'EOF'
=== Sample Data Testing Guide ===

To verify the new sample data files work correctly and demonstrate
misclassification matrices (Issue #14), follow these steps:

## Prerequisites

1. Start the backend server:
   cd backend
   Rscript run.R

2. Start the frontend dev server (in another terminal):
   cd frontend
   npm run dev

3. Open http://localhost:5173 in your browser

## Test Plan

### Test 1: openVA Sample - Neonate InterVA (Quick Test ~30s)
- Upload: frontend/public/sample_openva_neonate.csv
- Job Type: openVA
- Algorithm: InterVA
- Age Group: neonate
- Country: Mozambique
- Expected: Cause assignments + CSMF (no matrices)

### Test 2: openVA Sample - Child InSilicoVA (Accuracy Test ~2-3min)
- Upload: frontend/public/sample_openva_child.csv
- Job Type: openVA
- Algorithm: InSilicoVA
- Age Group: child
- Country: Kenya
- Expected: Cause assignments + CSMF (no matrices)

### Test 3: Pipeline Sample - Neonate with Matrix (CRITICAL ~1min)
- Upload: frontend/public/sample_openva_neonate.csv
- Job Type: Pipeline
- Algorithm: InterVA
- Age Group: neonate
- Country: Mozambique
- Expected: Causes + CSMF + Calibration + MISCLASSIFICATION MATRIX ✓
- Verify:
  ✓ Matrix appears in Results tab
  ✓ Table view shows exact probabilities
  ✓ Heatmap view shows color gradient
  ✓ CSV download link works

### Test 4: Pipeline Sample - Child Ensemble with Multiple Matrices (~3-4min)
- Upload: frontend/public/sample_openva_child.csv
- Job Type: Pipeline
- Algorithm: InterVA + InSilicoVA (ensemble)
- Age Group: child
- Country: Kenya
- Expected: Causes + CSMF + Calibration + MULTIPLE MATRICES ✓
- Verify:
  ✓ Separate matrix for InterVA
  ✓ Separate matrix for InSilicoVA
  ✓ Each matrix has table + heatmap views
  ✓ CSV downloads for both matrices

### Test 5: Vacalibration-Only Sample - Neonate (~1min)
- Upload: frontend/public/sample_vacalibration_neonate.csv
- Job Type: Calibration
- Algorithm: InterVA
- Age Group: neonate
- Country: South Africa
- Expected: Calibrated CSMF + MISCLASSIFICATION MATRIX ✓

### Test 6: Vacalibration-Only Sample - Child (~1min)
- Upload: frontend/public/sample_vacalibration_child.csv
- Job Type: Calibration
- Algorithm: InSilicoVA
- Age Group: child
- Country: Mali
- Expected: Calibrated CSMF + MISCLASSIFICATION MATRIX ✓

### Test 7: Demo vs Upload Consistency
- Run demo: "Neonate - InterVA - Mozambique (Pipeline)"
- Note the CSMF results and matrix data
- Upload: frontend/public/sample_openva_neonate.csv with same params
- Verify: Results match demo exactly ✓

## Validation Checklist

After running all tests, verify:

[ ] All 3 algorithms work (InterVA, InSilicoVA, EAVA)
[ ] Both age groups work (neonate, child)
[ ] Pipeline jobs show misclassification matrices
[ ] Ensemble jobs show multiple matrices (one per algorithm)
[ ] Matrix table view displays correctly
[ ] Matrix heatmap view displays correctly
[ ] Matrix CSV download works
[ ] Demo mode and CSV upload produce identical results
[ ] No encoding issues with CSV uploads
[ ] No errors in browser console or backend logs

## Quick Automated Test (Optional)

Run this command to verify all sample files exist:

ls -lh frontend/public/sample_*.csv

Expected output:
- sample_openva_neonate.csv (72K, 50 rows)
- sample_openva_child.csv (72K, 50 rows)
- sample_vacalibration_neonate.csv (2K, 81 rows)
- sample_vacalibration_child.csv (1.5K, 50 rows)

## Troubleshooting

If tests fail:
1. Check backend logs for errors
2. Check browser console for API errors
3. Verify backend server is running on http://localhost:8000
4. Verify frontend is running on http://localhost:5173
5. Re-run: Rscript backend/scripts/validate_samples.R

## Reporting Issues

If you find issues, report to GitHub:
gh issue comment 20 --body "Test results: [describe what you found]"

EOF
