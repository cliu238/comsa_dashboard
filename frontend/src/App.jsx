import { useState } from 'react';
import JobForm from './components/JobForm';
import JobList from './components/JobList';
import JobDetail from './components/JobDetail';
import DemoGallery from './components/DemoGallery';
import './App.css';

function App() {
  const [selectedJob, setSelectedJob] = useState(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const [activeTab, setActiveTab] = useState('submit'); // 'submit' or 'demos'
  const [videosExpanded, setVideosExpanded] = useState(true);

  const handleJobSubmitted = (jobId) => {
    setSelectedJob(jobId);
    setRefreshTrigger((n) => n + 1);
  };

  const handleDemoLaunch = (jobId) => {
    setSelectedJob(jobId);
    setRefreshTrigger((n) => n + 1);
    setActiveTab('submit'); // Switch back to main view after launching
  };

  const handleBack = () => {
    setSelectedJob(null);
    setRefreshTrigger((n) => n + 1);
  };

  return (
    <div className="app">
      <header>
        <h1>VA Calibration Platform</h1>
        <p>Process verbal autopsy data with openVA and vacalibration</p>
      </header>

      <section className="video-wrapper">
        <div className="video-card">
          <button
            className="video-toggle"
            onClick={() => setVideosExpanded(!videosExpanded)}
          >
            <span className={`toggle-icon ${videosExpanded ? 'expanded' : ''}`}>▶</span>
            Introduction Videos
          </button>
          {videosExpanded && (
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
        </div>
      </section>

      <main>
        {selectedJob ? (
          <JobDetail jobId={selectedJob} onBack={handleBack} />
        ) : (
          <>
            <div className="tabs">
              <button
                className={activeTab === 'submit' ? 'active' : ''}
                onClick={() => setActiveTab('submit')}
              >
                Submit Job
              </button>
              <button
                className={activeTab === 'demos' ? 'active' : ''}
                onClick={() => setActiveTab('demos')}
              >
                Demo Gallery
              </button>
            </div>

            <div className="tab-content">
              {activeTab === 'submit' ? (
                <div className="dashboard">
                  <JobForm onJobSubmitted={handleJobSubmitted} />
                  <JobList onSelectJob={setSelectedJob} refreshTrigger={refreshTrigger} />
                </div>
              ) : (
                <DemoGallery onDemoLaunch={handleDemoLaunch} />
              )}
            </div>
          </>
        )}
      </main>

      <footer>
        <p>Powered by openVA and vacalibration R packages</p>
      </footer>
    </div>
  );
}

export default App;
// Build: 1768949938
