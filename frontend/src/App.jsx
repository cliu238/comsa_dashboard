import { useState } from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import JobForm from './components/JobForm';
import JobList from './components/JobList';
import JobDetail from './components/JobDetail';
import DemoGallery from './components/DemoGallery';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import AdminPage from './pages/AdminPage';
import './App.css';

function Dashboard() {
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

  if (selectedJob) {
    return <JobDetail jobId={selectedJob} onBack={handleBack} />;
  }

  return (
    <div className="dashboard">
      <JobForm onJobSubmitted={handleJobSubmitted} />
      <JobList onSelectJob={setSelectedJob} refreshTrigger={refreshTrigger} />
    </div>
  );
}

function DemosPage() {
  const [selectedJob, setSelectedJob] = useState(null);

  const handleBack = () => {
    setSelectedJob(null);
  };

  if (selectedJob) {
    return <JobDetail jobId={selectedJob} onBack={handleBack} />;
  }

  return <DemoGallery onDemoLaunch={setSelectedJob} />;
}

function AppNav() {
  const { user, logout } = useAuth();
  const location = useLocation();

  if (!user) return null;

  return (
    <nav className="app-nav">
      <div className="nav-links">
        <Link to="/" className={location.pathname === '/' ? 'active' : ''}>Calibrate</Link>
        <Link to="/demos" className={location.pathname === '/demos' ? 'active' : ''}>Demo Gallery</Link>
        {user.role === 'admin' && (
          <Link to="/admin" className={location.pathname === '/admin' ? 'active' : ''}>Admin</Link>
        )}
      </div>
      <div className="nav-user">
        <span>{user.email}</span>
        <button onClick={logout} className="logout-btn">Sign Out</button>
      </div>
    </nav>
  );
}

function App() {
  const [videosExpanded, setVideosExpanded] = useState(false);

  return (
    <div className="app">
      <header>
        <h1>VA Calibration Platform</h1>
        <p>Process verbal autopsy data with openVA and vacalibration</p>
      </header>

      <AppNav />

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
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/" element={
            <ProtectedRoute><Dashboard /></ProtectedRoute>
          } />
          <Route path="/demos" element={
            <ProtectedRoute><DemosPage /></ProtectedRoute>
          } />
          <Route path="/admin" element={
            <ProtectedRoute adminOnly>
              <AdminPage />
            </ProtectedRoute>
          } />
        </Routes>
      </main>

      <footer>
        <p>Powered by Johns Hopkins Data Science and AI Institute (DSAI)</p>
      </footer>
    </div>
  );
}

export default App;
