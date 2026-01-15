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
