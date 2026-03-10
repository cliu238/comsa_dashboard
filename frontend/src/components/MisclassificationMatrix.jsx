import { useRef } from 'react';
import { exportMisclassMatrix, exportToPNG, exportToPDF, generateFilename } from '../utils/export';
import { getCellColor, isDiagonalCell } from '../utils/matrixUtils';
import { formatCauseDisplay, orderCauses } from '../utils/causeDisplay.js';

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

// Format cause names for heatmap (short version)
// Uses custom display names if available, otherwise uses abbreviations
function formatCauseShort(cause, displayNames) {
  // If custom display names exist, use a truncated version
  if (displayNames && displayNames[cause]) {
    const name = displayNames[cause];
    return name.length > 10 ? name.substring(0, 8) + '..' : name;
  }
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
  return shortMap[cause] || cause.substring(0, 8);
}

// Format algorithm names for display
function formatAlgorithmName(algo) {
  const algoMap = {
    'interva': 'InterVA',
    'insilicova': 'InSilicoVA',
    'eava': 'EAVA'
  };
  return algoMap[algo] || algo.toUpperCase();
}

// Table view component
function MatrixTable({ algoName, matrixData, jobId, causeDisplayNames, causeOrder }) {
  const { matrix, champs_causes, va_causes } = reorderMatrixData(matrixData, causeOrder);
  const tableRef = useRef(null);

  const exportData = { matrix, rowLabels: champs_causes, colLabels: va_causes };
  const algoDisplay = formatAlgorithmName(algoName);

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
              {va_causes.map(cause => (
                <th key={cause} className="va-header" title={formatCauseDisplay(cause, causeDisplayNames)}>
                  {formatCauseShort(cause, causeDisplayNames)}
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
                      title={`P(VA=${va_causes[colIdx]} | CHAMPS=${champsCause}) = ${value.toFixed(4)}${diag ? ' [Sensitivity]' : ''}`}
                    >
                      {value.toFixed(3)}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
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
        <span className="diagonal-indicator"></span> Diagonal = Sensitivity (correct classification)
      </div>
    </div>
  );
}

// Main component
export function MisclassificationMatrix({ matrixData, jobId, causeDisplayNames, causeOrder }) {
  if (!matrixData || Object.keys(matrixData).length === 0) {
    return null;
  }

  const algorithms = Object.keys(matrixData);

  return (
    <div className="misclass-section">
      <h3>Misclassification Matrix</h3>
      <p className="matrix-description">
        Shows the probability P(VA cause | CHAMPS cause) - how often each CHAMPS cause is
        classified as each VA cause by the algorithm. Rows are CHAMPS causes (true causes),
        columns are VA causes (predicted causes).
      </p>

      {algorithms.map(algoName => (
        <div key={algoName} className="algorithm-matrix">
          <h3>{formatAlgorithmName(algoName)}</h3>

          <MatrixTable algoName={algoName} matrixData={matrixData[algoName]} jobId={jobId} causeDisplayNames={causeDisplayNames} causeOrder={causeOrder} />
        </div>
      ))}
    </div>
  );
}
