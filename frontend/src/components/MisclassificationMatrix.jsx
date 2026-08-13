import { useRef } from 'react';
import { exportMisclassMatrix, exportToPNG, exportToPDF, generateFilename } from '../utils/export';
import { getCellColor, isDiagonalCell } from '../utils/matrixUtils';
import { formatCauseDisplay, orderCauses } from '../utils/causeDisplay.js';
import { formatAlgorithmName } from '../utils/labels.js';

// Reorder matrix axes according to causeOrder
function reorderMatrixData(matrixData, causeOrder) {
  if (!causeOrder) return matrixData;
  const { matrix, champs_causes, va_causes } = matrixData;
  const newChamps = orderCauses(champs_causes, causeOrder);
  const newVa = orderCauses(va_causes, causeOrder);
  const champsPerm = newChamps.map(c => champs_causes.indexOf(c));
  const vaPerm = newVa.map(c => va_causes.indexOf(c));
  const newMatrix = champsPerm.map(ri => vaPerm.map(ci => matrix[ri][ci]));
  return { matrix: newMatrix, champs_causes: newChamps, va_causes: newVa };
}

// Built-in abbreviation for a known broad cause code. An UNKNOWN code is returned
// whole: pre-truncating here would collide two codes sharing a prefix before
// shortenUnique() ever sees them, and since it derives its target from the labels
// it is handed, it would read that collision as intended and leave the header
// ambiguous. Truncation is shortenUnique()'s job alone.
function builtInShort(cause) {
  const shortMap = {
    'congenital_malformation': 'Cong Malf',
    'pneumonia': 'Pneum',
    'sepsis_meningitis_inf': 'Sepsis/Men',
    'ipre': 'IPRE',
    'other': 'Other',
    'prematurity': 'Premat',
    'malaria': 'Malaria',
    'diarrhea': 'Diarr',
    'severe_malnutrition': 'Malnut',
    'hiv': 'HIV',
    'injury': 'Injury',
    'other_infections': 'Oth Inf',
    'nn_causes': 'NN Causes'
  };
  return shortMap[cause] || cause;
}

// Truncate to at most `max` characters, marking the cut with '..'.
function truncate(label, max) {
  return label.length > max ? label.substring(0, max - 2) + '..' : label;
}

// Shorten labels, but never to the point where two different causes render
// identically. Truncating at a fixed offset made both "Neonatal sepsis" and
// "Neonatal pneumonia" read "Neonatal.." (issue #104), so grow the character
// budget until every label is distinguishable, and fall back to the untruncated
// names rather than render an ambiguous header row.
function shortenUnique(labels, min = 10, max = 24) {
  const distinct = new Set(labels).size;
  for (let n = min; n <= max; n += 2) {
    const out = labels.map(l => truncate(l, n));
    if (new Set(out).size === distinct) return out;
  }
  return labels;
}

// Column header labels: short, and guaranteed distinguishable within this table.
function headerLabels(causes, displayNames) {
  return shortenUnique(causes.map(cause =>
    displayNames && displayNames[cause] ? displayNames[cause] : builtInShort(cause)
  ));
}

// `not_calibrated` arrives from the API as a JSON array, or as a bare string
// when it holds a single cause (R's toJSON auto-unboxes length-1 vectors).
function asCauseList(value) {
  if (value == null) return [];
  return Array.isArray(value) ? value : [value];
}

// Table view component
function MatrixTable({ algoName, matrixData, jobId, causeDisplayNames, causeOrder }) {
  const { matrix, champs_causes, va_causes } = reorderMatrixData(matrixData, causeOrder);
  const tableRef = useRef(null);

  const exportData = { matrix, rowLabels: champs_causes, colLabels: va_causes };
  const algoDisplay = formatAlgorithmName(algoName);
  const vaHeaders = headerLabels(va_causes, causeDisplayNames);
  const notCalibrated = asCauseList(matrixData.not_calibrated);

  return (
    <div className="matrix-table-container">
      <div className="section-header">
        <h4>{algoDisplay} - Misclassification Matrix</h4>
        <div className="export-buttons">
          <button onClick={() => exportMisclassMatrix(exportData, algoDisplay, jobId)} className="export-btn" title="Export as CSV">CSV ↓</button>
          <button onClick={() => exportToPNG(tableRef, generateFilename('misclass_matrix', algoDisplay, jobId, 'png'))} className="export-btn" title="Export as PNG">PNG ↓</button>
          <button onClick={() => exportToPDF(tableRef, generateFilename('misclass_matrix', algoDisplay, jobId, 'pdf'))} className="export-btn" title="Export as PDF">PDF ↓</button>
        </div>
      </div>
      <div ref={tableRef} className="table-responsive">
        <table className="misclass-table">
          <thead>
            <tr>
              <th className="corner-cell">CHAMPS \ VA</th>
              {va_causes.map((cause, colIdx) => (
                <th key={cause} className="va-header" title={formatCauseDisplay(cause, causeDisplayNames)}>
                  {vaHeaders[colIdx]}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {champs_causes.map((champsCause, rowIdx) => (
              <tr key={champsCause}>
                <th className="champs-header" title={formatCauseDisplay(champsCause, causeDisplayNames)}>
                  {formatCauseDisplay(champsCause, causeDisplayNames)}
                </th>
                {matrix[rowIdx].map((value, colIdx) => {
                  const bgColor = getCellColor(value);
                  const diag = isDiagonalCell(rowIdx, colIdx, champs_causes, va_causes);
                  const textColor = value > 0.7 ? '#fff' : '#1e3a5f';
                  return (
                    <td
                      key={`${rowIdx}-${colIdx}`}
                      className={`matrix-cell${diag ? ' diagonal-cell' : ''}`}
                      style={{ backgroundColor: bgColor, color: textColor }}
                      title={`P(VA=${va_causes[colIdx]} | CHAMPS=${champsCause}) = ${(value * 100).toFixed(1)}%${diag ? ' [diagonal — retained mass, not empirical sensitivity]' : ''}`}
                    >
                      {Math.round(value * 100)}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {notCalibrated.length > 0 && (
        <p className="matrix-not-calibrated">
          Not calibrated, so absent from this matrix:{' '}
          {notCalibrated.map(c => formatCauseDisplay(c, causeDisplayNames)).join(', ')}.
          vacalibration excludes these causes from calibration, and its own matrix
          leaves their row and column blank.
        </p>
      )}
      <MatrixLegend />
    </div>
  );
}

// Legend component for the matrix
function MatrixLegend() {
  return (
    <div className="heatmap-legend">
      <div className="legend-label">Probability:</div>
      <div className="legend-gradient"></div>
      <div className="legend-labels">
        <span>0.0 (Low)</span>
        <span>0.5 (Medium)</span>
        <span>1.0 (High)</span>
      </div>
      <div className="legend-diagonal">
        <span className="diagonal-indicator"></span> Diagonal = mass retained on the same cause
      </div>
    </div>
  );
}

// Main component
export function MisclassificationMatrix({ matrixData, jobId, causeDisplayNames, causeOrder, lambda, ciUnreliable }) {
  if (!matrixData || Object.keys(matrixData).length === 0) {
    return null;
  }

  const algorithms = Object.keys(matrixData);

  return (
    <div className="misclass-section">
      {/* issue #116: this is vacalibration's `Mmat_tomodel`, which its own plot titles
          "Prior Mean of Misclassification Matrix — Used For Calibration". It is the
          identity matrix mixed with the CHAMPS estimate at the path-correction λ, so its
          diagonal is NOT the empirical sensitivity — on the shipped child/Ethiopia demo
          (λ = 0.41, not even stalled) the diagonal averages 0.51 against the CHAMPS
          estimate's 0.33, and at λ = 0.99 it reads ~0.99 against a real 0.135 for
          malaria. The panel used to caption that diagonal "sensitivity". */}
      <h3>Misclassification Matrices — Used For Calibration</h3>
      <p className="matrix-description">
        P(VA cause | CHAMPS cause) for the prior mean vacalibration actually calibrated
        with. Rows = CHAMPS causes, columns = VA causes. This is the CHAMPS estimate mixed
        with the identity matrix at the path-correction λ
        {typeof lambda === 'number' ? ` (λ = ${lambda.toFixed(2)})` : ''}, so the diagonal
        is the mass each cause retains under that mixture — <strong>not</strong> the
        algorithm's empirical sensitivity, which is lower.
      </p>
      {ciUnreliable && (
        <p className="matrix-stall-note">
          Path correction could only use λ
          {typeof lambda === 'number' ? ` = ${lambda.toFixed(2)}` : ' at its ceiling'}, so
          this matrix is close to the identity and says little about misclassification.
          The underlying CHAMPS estimate is unchanged and much further off-diagonal.
        </p>
      )}

      <div className="matrix-small-multiples">
        {algorithms.map(algoName => (
          <div key={algoName} className="algorithm-matrix">
            <MatrixTable algoName={algoName} matrixData={matrixData[algoName]} jobId={jobId} causeDisplayNames={causeDisplayNames} causeOrder={causeOrder} />
          </div>
        ))}
      </div>
    </div>
  );
}
