import { useState, useEffect } from 'react';
import './DemoGallery.css';

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

export default function DemoGallery({ onDemoLaunch }) {
  const [demos, setDemos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');
  const [launching, setLaunching] = useState(null);

  useEffect(() => {
    fetchDemos();
  }, []);

  async function fetchDemos() {
    try {
      const response = await fetch(`${API_BASE}/demos/list`);
      const data = await response.json();
      setDemos(data.demos || []);
    } catch (err) {
      setError('Failed to load demos: ' + err.message);
    } finally {
      setLoading(false);
    }
  }

  async function launchDemo(demoId, demoName) {
    setLaunching(demoId);
    setError(null);

    try {
      const response = await fetch(`${API_BASE}/demos/launch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ demo_id: demoId })
      });

      const result = await response.json();

      if (result.error) {
        setError(result.error);
      } else {
        if (onDemoLaunch) {
          onDemoLaunch(result.job_id);
        }
      }
    } catch (err) {
      setError('Failed to launch demo: ' + err.message);
    } finally {
      setLaunching(null);
    }
  }

  const filteredDemos = demos.filter(demo => {
    if (filter === 'all') return true;
    if (filter === 'neonate') return demo.age_group === 'neonate';
    if (filter === 'child') return demo.age_group === 'child';
    if (filter === 'ensemble') return demo.ensemble === true;
    if (filter === 'single') return demo.ensemble === false;
    if (filter === 'openva') return demo.job_type === 'openva';
    if (filter === 'pipeline') return demo.job_type === 'pipeline';
    if (filter === 'vacalibration') return demo.job_type === 'vacalibration';
    return true;
  });

  if (loading) {
    return <div className="demo-gallery"><p>Loading demos...</p></div>;
  }

  return (
    <div className="demo-gallery">
      <div className="demo-gallery-header">
        <h2>Pre-configured Demo Scenarios</h2>
        <p className="demo-gallery-description">
          Explore different configurations with sample data. Each demo runs with pre-set parameters to demonstrate specific use cases.
        </p>
      </div>

      <div className="demo-filters">
        <button
          className={filter === 'all' ? 'active' : ''}
          onClick={() => setFilter('all')}
        >
          All ({demos.length})
        </button>
        <button
          className={filter === 'neonate' ? 'active' : ''}
          onClick={() => setFilter('neonate')}
        >
          Neonate
        </button>
        <button
          className={filter === 'child' ? 'active' : ''}
          onClick={() => setFilter('child')}
        >
          Child
        </button>
        <button
          className={filter === 'ensemble' ? 'active' : ''}
          onClick={() => setFilter('ensemble')}
        >
          Ensemble
        </button>
        <button
          className={filter === 'single' ? 'active' : ''}
          onClick={() => setFilter('single')}
        >
          Single Algorithm
        </button>
        <button
          className={filter === 'openva' ? 'active' : ''}
          onClick={() => setFilter('openva')}
        >
          openVA Only
        </button>
        <button
          className={filter === 'pipeline' ? 'active' : ''}
          onClick={() => setFilter('pipeline')}
        >
          Pipeline
        </button>
        <button
          className={filter === 'vacalibration' ? 'active' : ''}
          onClick={() => setFilter('vacalibration')}
        >
          Calibration
        </button>
      </div>

      {error && <div className="demo-error">{error}</div>}

      <div className="demo-grid">
        {filteredDemos.map(demo => (
          <div key={demo.id} className="demo-card">
            <div className="demo-card-header">
              <h3>{demo.name}</h3>
              <span className={`demo-badge ${demo.job_type}`}>
                {demo.job_type}
              </span>
            </div>

            <p className="demo-description">{demo.description}</p>

            <div className="demo-details">
              <div className="demo-detail">
                <strong>Algorithm:</strong>{' '}
                {Array.isArray(demo.algorithm)
                  ? demo.algorithm.join(' + ')
                  : demo.algorithm}
              </div>
              <div className="demo-detail">
                <strong>Age Group:</strong> {demo.age_group}
              </div>
              <div className="demo-detail">
                <strong>Country:</strong> {demo.country}
              </div>
              <div className="demo-detail">
                <strong>Time:</strong> {demo.estimated_time}
              </div>
            </div>

            <div className="demo-tags">
              {demo.tags && demo.tags.map(tag => (
                <span key={tag} className="demo-tag">{tag}</span>
              ))}
            </div>

            <button
              className="demo-launch-btn"
              onClick={() => launchDemo(demo.id, demo.name)}
              disabled={launching === demo.id}
            >
              {launching === demo.id ? 'Launching...' : 'Run This Demo'}
            </button>
          </div>
        ))}
      </div>

      {filteredDemos.length === 0 && (
        <p className="no-demos">No demos match the selected filter.</p>
      )}
    </div>
  );
}
