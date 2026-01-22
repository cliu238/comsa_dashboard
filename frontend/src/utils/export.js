/**
 * Export utilities for downloading tables and figures
 */

/**
 * Generate standardized filename for exports
 * Format: {component}_{algorithm}_{jobId}_{timestamp}.{ext}
 */
export function generateFilename(type, algorithm, jobId, extension) {
  const timestamp = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const cleanAlgo = algorithm?.replace(/\s+/g, '_') || 'unknown';
  const cleanJobId = jobId?.substring(0, 8) || 'job';
  return `${type}_${cleanAlgo}_${cleanJobId}_${timestamp}.${extension}`;
}

/**
 * Trigger browser download for a blob
 */
function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Export data to CSV file
 */
export function exportToCSV(csvContent, filename) {
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  downloadBlob(blob, filename);
}

/**
 * Export CSMF table to CSV
 * Handles both calibrated (vacalibration) and uncalibrated (openVA) results
 */
export function exportCSMFTable(results, jobId, algorithm) {
  if (!results) return;

  let csvContent = '';

  // Check if this is calibrated results (has csmf_calibrated)
  if (results.csmf_calibrated) {
    // Calibrated results: compare uncalibrated vs calibrated
    csvContent = 'Cause,Uncalibrated (%),Calibrated (%),Lower CI,Upper CI\n';

    const causes = Object.keys(results.csmf_uncalibrated);
    causes.forEach(cause => {
      const uncal = (results.csmf_uncalibrated[cause] * 100).toFixed(2);
      const cal = (results.csmf_calibrated[cause] * 100).toFixed(2);
      const lower = results.csmf_intervals?.[cause]?.lower
        ? (results.csmf_intervals[cause].lower * 100).toFixed(2)
        : '';
      const upper = results.csmf_intervals?.[cause]?.upper
        ? (results.csmf_intervals[cause].upper * 100).toFixed(2)
        : '';

      csvContent += `"${cause}",${uncal},${cal},${lower},${upper}\n`;
    });
  } else if (results.csmf) {
    // OpenVA results: just CSMF values
    csvContent = 'Cause,CSMF (%)\n';

    const causes = Object.keys(results.csmf);
    causes.forEach(cause => {
      const value = (results.csmf[cause] * 100).toFixed(2);
      csvContent += `"${cause}",${value}\n`;
    });
  }

  const filename = generateFilename('csmf_table', algorithm, jobId, 'csv');
  exportToCSV(csvContent, filename);
}

/**
 * Export misclassification matrix to CSV
 * matrixData: { matrix: 2D array, rowLabels: [], colLabels: [] }
 */
export function exportMisclassMatrix(matrixData, algoName, jobId) {
  if (!matrixData || !matrixData.matrix) return;

  const { matrix, rowLabels, colLabels } = matrixData;

  // Header row: empty cell + column labels (VA predictions)
  let csvContent = ',' + colLabels.map(col => `"${col}"`).join(',') + '\n';

  // Data rows: row label (CHAMPS) + values
  matrix.forEach((row, i) => {
    const rowLabel = rowLabels[i];
    const values = row.map(val => val.toFixed(4)).join(',');
    csvContent += `"${rowLabel}",${values}\n`;
  });

  const filename = generateFilename('misclass_matrix', algoName, jobId, 'csv');
  exportToCSV(csvContent, filename);
}

/**
 * Export element to PNG image (async, requires html2canvas)
 */
export async function exportToPNG(elementRef, filename) {
  if (!elementRef || !elementRef.current) {
    console.error('Invalid element reference for PNG export');
    return;
  }

  try {
    // Dynamic import to avoid loading html2canvas until needed
    const html2canvas = (await import('html2canvas')).default;

    const canvas = await html2canvas(elementRef.current, {
      backgroundColor: '#ffffff',
      scale: 2, // Higher resolution
      logging: false
    });

    canvas.toBlob((blob) => {
      if (blob) {
        downloadBlob(blob, filename);
      }
    }, 'image/png');
  } catch (error) {
    console.error('Error exporting to PNG:', error);
    alert('Failed to export image. Please try again.');
  }
}
