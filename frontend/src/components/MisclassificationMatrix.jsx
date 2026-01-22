import React, { useRef } from 'react';
import { exportMisclassMatrix, exportToPNG, generateFilename } from '../utils/export';

// Color gradient: Blue (low) -> Yellow (medium) -> Red (high)
function getCellColor(value) {
  if (value < 0.33) {
    // Blue to Yellow
    const ratio = value / 0.33;
    const r = Math.round(173 + (255 - 173) * ratio);
    const g = Math.round(216 + (255 - 216) * ratio);
    const b = Math.round(230 + (0 - 230) * ratio);
    return `rgb(${r}, ${g}, ${b})`;
  } else if (value < 0.67) {
    // Yellow to Orange
    const ratio = (value - 0.33) / 0.34;
    const r = 255;
    const g = Math.round(255 - (255 - 165) * ratio);
    const b = 0;
    return `rgb(${r}, ${g}, ${b})`;
  } else {
    // Orange to Red
    const ratio = (value - 0.67) / 0.33;
    const r = 255;
    const g = Math.round(165 - 165 * ratio);
    const b = 0;
    return `rgb(${r}, ${g}, ${b})`;
  }
}

// Format cause names for display
function formatCause(cause) {
  const causeMap = {
    'congenital_malformation': 'Congenital Malformation',
    'pneumonia': 'Pneumonia',
    'sepsis_meningitis_inf': 'Sepsis/Meningitis/Infection',
    'ipre': 'Intrapartum-Related Event',
    'other': 'Other',
    'prematurity': 'Prematurity',
    'malaria': 'Malaria',
    'diarrhea': 'Diarrhea',
    'severe_malnutrition': 'Severe Malnutrition',
    'hiv': 'HIV/AIDS',
    'injury': 'Injury',
    'other_infections': 'Other Infections',
    'nn_causes': 'Neonatal Causes'
  };
  return causeMap[cause] || cause.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

// Format cause names for heatmap (short version)
function formatCauseShort(cause) {
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
function MatrixTable({ algoName, matrixData, jobId }) {
  const { matrix, champs_causes, va_causes } = matrixData;

  // Prepare data for CSV export
  const exportData = {
    matrix: matrix,
    rowLabels: champs_causes,
    colLabels: va_causes
  };

  return (
    <div className="matrix-table-container">
      <div className="section-header">
        <h4>{formatAlgorithmName(algoName)} - Table View</h4>
        <button
          onClick={() => exportMisclassMatrix(exportData, formatAlgorithmName(algoName), jobId)}
          className="export-btn"
          title="Export misclassification matrix table as CSV"
        >
          CSV ↓
        </button>
      </div>
      <div className="table-responsive">
        <table className="misclass-table">
          <thead>
            <tr>
              <th className="corner-cell">CHAMPS \ VA</th>
              {va_causes.map(cause => (
                <th key={cause} className="va-header" title={formatCause(cause)}>
                  {formatCauseShort(cause)}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {champs_causes.map((champsCause, rowIdx) => (
              <tr key={champsCause}>
                <th className="champs-header" title={formatCause(champsCause)}>
                  {formatCause(champsCause)}
                </th>
                {matrix[rowIdx].map((value, colIdx) => {
                  const bgColor = getCellColor(value);
                  const textColor = value > 0.5 ? '#fff' : '#000';
                  return (
                    <td
                      key={`${rowIdx}-${colIdx}`}
                      className="matrix-cell"
                      style={{ backgroundColor: bgColor, color: textColor }}
                      title={`P(VA=${va_causes[colIdx]} | CHAMPS=${champsCause}) = ${value.toFixed(4)}`}
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
    </div>
  );
}

// Heatmap view component
function MatrixHeatmap({ algoName, matrixData, jobId }) {
  const { matrix, champs_causes, va_causes } = matrixData;
  const heatmapRef = useRef(null);

  return (
    <div className="matrix-heatmap-container">
      <div className="section-header">
        <h4>{formatAlgorithmName(algoName)} - Heatmap View</h4>
        <button
          onClick={() => exportToPNG(heatmapRef, generateFilename('misclass_heatmap', formatAlgorithmName(algoName), jobId, 'png'))}
          className="export-btn"
          title="Export misclassification matrix heatmap as PNG"
        >
          PNG ↓
        </button>
      </div>
      <div ref={heatmapRef} className="heatmap-wrapper">
        <div className="heatmap-grid" style={{ gridTemplateColumns: `120px repeat(${va_causes.length}, 1fr)` }}>
          {/* Corner cell */}
          <div className="heatmap-corner">CHAMPS \ VA</div>

          {/* VA cause headers */}
          {va_causes.map(cause => (
            <div key={cause} className="heatmap-header va-header" title={formatCause(cause)}>
              {formatCauseShort(cause)}
            </div>
          ))}

          {/* Matrix rows */}
          {champs_causes.map((champsCause, rowIdx) => (
            <React.Fragment key={champsCause}>
              {/* CHAMPS cause label */}
              <div className="heatmap-header champs-header" title={formatCause(champsCause)}>
                {formatCauseShort(champsCause)}
              </div>

              {/* Cell values */}
              {matrix[rowIdx].map((value, colIdx) => {
                const bgColor = getCellColor(value);
                const textColor = value > 0.5 ? '#fff' : '#000';
                return (
                  <div
                    key={`${rowIdx}-${colIdx}`}
                    className="heatmap-cell"
                    style={{ backgroundColor: bgColor, color: textColor }}
                    title={`P(VA=${va_causes[colIdx]} | CHAMPS=${champsCause}) = ${value.toFixed(4)}`}
                  >
                    {value.toFixed(2)}
                  </div>
                );
              })}
            </React.Fragment>
          ))}
        </div>

        {/* Color legend */}
        <div className="heatmap-legend">
          <div className="legend-label">Probability:</div>
          <div className="legend-gradient"></div>
          <div className="legend-labels">
            <span>0.0 (Low)</span>
            <span>0.5 (Medium)</span>
            <span>1.0 (High)</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// Main component
export function MisclassificationMatrix({ matrixData, jobId }) {
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

          <MatrixTable algoName={algoName} matrixData={matrixData[algoName]} jobId={jobId} />

          <MatrixHeatmap algoName={algoName} matrixData={matrixData[algoName]} jobId={jobId} />
        </div>
      ))}
    </div>
  );
}
