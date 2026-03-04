// Color gradient: White (low) -> Light Red (medium) -> Deep Red (high)
export function getCellColor(value) {
  if (value < 0.5) {
    // White to Light Red (red stays 255, g/b decrease)
    const ratio = value / 0.5;
    const r = 255;
    const g = Math.round(255 - (255 - 180) * ratio);
    const b = Math.round(255 - (255 - 180) * ratio);
    return `rgb(${r}, ${g}, ${b})`;
  } else {
    // Light Red to Deep Red (all channels decrease)
    const ratio = (value - 0.5) / 0.5;
    const r = Math.round(255 - (255 - 180) * ratio);
    const g = Math.round(180 - (180 - 30) * ratio);
    const b = Math.round(180 - (180 - 30) * ratio);
    return `rgb(${r}, ${g}, ${b})`;
  }
}

// Check if a cell is on the "diagonal" (CHAMPS cause == VA cause = correct classification)
export function isDiagonalCell(rowIdx, colIdx, champsCauses, vaCauses) {
  return champsCauses[rowIdx] === vaCauses[colIdx];
}
