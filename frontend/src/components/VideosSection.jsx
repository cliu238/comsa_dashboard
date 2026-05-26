import { useState } from 'react';

const videoIcon = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="2" y="3" width="20" height="14" rx="2" /><path d="m7 21 5-3 5 3" />
  </svg>
);

export default function VideosSection({ defaultExpanded = false }) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  return (
    <section className="videos-section">
      <button className="videos-toggle" onClick={() => setExpanded(!expanded)}>
        <span className="videos-toggle-icon">{videoIcon}</span>
        <span>Introduction Videos</span>
        <span className={`videos-chevron ${expanded ? 'expanded' : ''}`}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </span>
      </button>
      {expanded && (
        <div className="video-grid">
          <div className="video-item">
            <h4>Platform Overview</h4>
            <p>Introduction to the Verbal Autopsy Calibration Platform</p>
            <video controls>
              <source src={`${import.meta.env.BASE_URL}VacalibrationVideo.mp4`} type="video/mp4" />
            </video>
          </div>
          <div className="video-item">
            <h4>Methodology Details</h4>
            <p>Technical explanation of the Bayesian calibration methodology</p>
            <video controls>
              <source src={`${import.meta.env.BASE_URL}vacalibration-full-method.mp4`} type="video/mp4" />
            </video>
          </div>
        </div>
      )}
    </section>
  );
}
