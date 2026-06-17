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
 * Render an element to a canvas, capturing its FULL scrollable size rather than
 * just the visible viewport. Horizontally-scrolling content (e.g. the CSMF
 * facet row, which overflows when there are 3 CCVAs + Ensemble) is un-clipped
 * in the cloned DOM so every facet is exported, not just the visible ones.
 * (issue #78)
 */
async function captureElement(element) {
  const html2canvas = (await import('html2canvas')).default;
  return html2canvas(element, {
    backgroundColor: '#ffffff',
    scale: 2, // Higher resolution
    logging: false,
    width: element.scrollWidth,
    height: element.scrollHeight,
    windowWidth: element.scrollWidth,
    onclone: (clonedDoc) => {
      clonedDoc.querySelectorAll('.csmf-facets').forEach((node) => {
        node.style.overflow = 'visible';
        node.style.width = 'max-content';
      });
    },
  });
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
    const canvas = await captureElement(elementRef.current);

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

/**
 * Export the consolidated CSMF table to CSV.
 * tableData: { causes: [...], groups: [{ algorithm, rows: [{ type, cells: [{cause, mean, lower, upper}] }] }] }
 */
export function exportConsolidatedCSMF(tableData, jobId, algorithm) {
  if (!tableData || !tableData.groups) return;
  const { causes, groups } = tableData;

  let csvContent = 'Algorithm,Type,' + causes.map(c => `"${c}"`).join(',') + '\n';
  groups.forEach(group => {
    group.rows.forEach(row => {
      const cells = row.cells.map(cell => {
        if (cell.mean == null) return '';
        return cell.lower != null && cell.upper != null
          ? `"${cell.mean} (${cell.lower}, ${cell.upper})"`
          : `${cell.mean}`;
      });
      csvContent += `"${group.algorithm}","${row.type}",${cells.join(',')}\n`;
    });
  });

  const filename = generateFilename('csmf_table', algorithm, jobId, 'csv');
  exportToCSV(csvContent, filename);
}

/**
 * Export element to PDF (async, requires html2canvas + jspdf)
 */
export async function exportToPDF(elementRef, filename) {
  if (!elementRef || !elementRef.current) {
    console.error('Invalid element reference for PDF export');
    return;
  }

  try {
    const { jsPDF } = await import('jspdf');

    const canvas = await captureElement(elementRef.current);

    const imgData = canvas.toDataURL('image/png');
    const imgWidth = canvas.width;
    const imgHeight = canvas.height;

    // Landscape or portrait based on aspect ratio
    const orientation = imgWidth > imgHeight ? 'landscape' : 'portrait';
    const pdf = new jsPDF(orientation, 'pt', 'a4');

    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const margin = 40;
    const maxWidth = pageWidth - margin * 2;
    const maxHeight = pageHeight - margin * 2;

    // Scale to fit page
    const scale = Math.min(maxWidth / imgWidth, maxHeight / imgHeight);
    const w = imgWidth * scale;
    const h = imgHeight * scale;
    const x = (pageWidth - w) / 2;
    const y = (pageHeight - h) / 2;

    pdf.addImage(imgData, 'PNG', x, y, w, h);
    pdf.save(filename);
  } catch (error) {
    console.error('Error exporting to PDF:', error);
    alert('Failed to export PDF. Please try again.');
  }
}

/**
 * Export several result sections into ONE combined PDF (issue #91): the run
 * inputs, the misclassification figure, the CSMF figure, and the summary table.
 *
 * sections: array of { ref } where ref is a React ref ({ current: HTMLElement }).
 * Sections whose ref is empty are skipped (e.g. no misclassification matrix), so
 * callers can pass the full list unconditionally. Each section is captured at
 * full width (reusing captureElement, so the #78 facet un-clipping applies) and
 * stacked top-to-bottom across A4 pages: a section that does not fit the
 * remaining space starts a new page, and one taller than a full page is scaled
 * down to fit a single page.
 */
export async function exportCombinedPDF(sections, filename) {
  const valid = (sections || []).filter((s) => s && s.ref && s.ref.current);
  if (valid.length === 0) {
    console.error('No sections available for combined PDF export');
    return;
  }

  try {
    const { jsPDF } = await import('jspdf');
    const pdf = new jsPDF('portrait', 'pt', 'a4');

    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const margin = 40;
    const gap = margin / 2;
    const maxWidth = pageWidth - margin * 2;
    const maxHeight = pageHeight - margin * 2;

    let cursorY = margin;
    for (const section of valid) {
      const canvas = await captureElement(section.ref.current);
      const imgData = canvas.toDataURL('image/png');

      // Scale to the content width, capping height to a single page.
      let w = maxWidth;
      let h = (canvas.height / canvas.width) * w;
      if (h > maxHeight) {
        h = maxHeight;
        w = (canvas.width / canvas.height) * h;
      }

      // Start a new page when the section would overflow the remaining space
      // (but never for the first placement on a fresh page).
      if (cursorY > margin && cursorY + h > pageHeight - margin) {
        pdf.addPage();
        cursorY = margin;
      }

      const x = margin + (maxWidth - w) / 2;
      pdf.addImage(imgData, 'PNG', x, cursorY, w, h);
      cursorY += h + gap;
    }

    pdf.save(filename);
  } catch (error) {
    console.error('Error exporting combined PDF:', error);
    alert('Failed to export combined PDF. Please try again.');
  }
}
