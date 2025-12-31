import { useState } from 'react';
import JobForm from './components/JobForm';
import JobList from './components/JobList';
import JobDetail from './components/JobDetail';
import './App.css';

function App() {
  const [selectedJob, setSelectedJob] = useState(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const handleJobSubmitted = (jobId) => {
    setSelectedJob(jobId);
    setRefreshTrigger((n) => n + 1);
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
          <div className="dashboard">
            <JobForm onJobSubmitted={handleJobSubmitted} />
            <JobList onSelectJob={setSelectedJob} refreshTrigger={refreshTrigger} />
          </div>
        )}
      </main>

      <footer>
        <p>Powered by openVA and vacalibration R packages</p>
      </footer>
    </div>
  );
}

export default App;
