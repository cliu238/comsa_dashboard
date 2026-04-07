import { useState } from 'react';
import { Routes, Route, Link, useLocation, Navigate } from 'react-router-dom';
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

/* Sidebar icons as inline SVGs for zero dependencies */
const icons = {
  calibrate: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 20V10" /><path d="M18 20V4" /><path d="M6 20v-4" />
    </svg>
  ),
  demos: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="5 3 19 12 5 21 5 3" />
    </svg>
  ),
  admin: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  ),
  video: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="3" width="20" height="14" rx="2" /><path d="m7 21 5-3 5 3" />
    </svg>
  ),
  logout: (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><polyline points="16 17 21 12 16 7" /><line x1="21" y1="12" x2="9" y2="12" />
    </svg>
  ),
};

function Sidebar() {
  const { user, logout } = useAuth();
  const location = useLocation();

  if (!user) return null;

  const navItems = [
    { path: '/', label: 'Calibrate', icon: icons.calibrate },
    { path: '/demos', label: 'Demo Gallery', icon: icons.demos },
  ];

  if (user.role === 'admin') {
    navItems.push({ path: '/admin', label: 'Users', icon: icons.admin });
  }

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="sidebar-logo">
          <span className="logo-mark">VA</span>
        </div>
        <div className="sidebar-title">
          <span className="brand-name">VA Calibration</span>
          <span className="brand-sub">Platform</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <div className="nav-section-label">Navigation</div>
        {navItems.map(({ path, label, icon }) => (
          <Link
            key={path}
            to={path}
            className={`sidebar-link ${location.pathname === path ? 'active' : ''}`}
          >
            <span className="sidebar-icon">{icon}</span>
            {label}
          </Link>
        ))}
      </nav>

      <div className="sidebar-footer">
        <div className="sidebar-user">
          <div className="user-avatar">
            {(user.name || user.email)[0].toUpperCase()}
          </div>
          <div className="user-info">
            <span className="user-name">{user.name || 'User'}</span>
            <span className="user-email">{user.email}</span>
          </div>
        </div>
        <button onClick={logout} className="sidebar-logout" title="Sign Out">
          {icons.logout}
        </button>
      </div>
    </aside>
  );
}

function PageHeader({ title, subtitle }) {
  return (
    <div className="page-header">
      <h1 className="page-title">{title}</h1>
      {subtitle && <p className="page-subtitle">{subtitle}</p>}
    </div>
  );
}

function VideosSection() {
  const [expanded, setExpanded] = useState(false);

  return (
    <section className="videos-section">
      <button className="videos-toggle" onClick={() => setExpanded(!expanded)}>
        <span className="videos-toggle-icon">{icons.video}</span>
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

function App() {
  const { user } = useAuth();

  return (
    <div className={`app-layout ${user ? 'with-sidebar' : ''}`}>
      <Sidebar />

      <div className="app-main">
        <main>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />
            <Route path="/" element={
              <ProtectedRoute>
                <PageHeader title="Calibrate" subtitle="Submit and monitor verbal autopsy calibration jobs" />
                <VideosSection />
                <Dashboard />
              </ProtectedRoute>
            } />
            <Route path="/demos" element={
              <ProtectedRoute>
                <PageHeader title="Demo Gallery" subtitle="Explore pre-configured calibration demos" />
                <DemosPage />
              </ProtectedRoute>
            } />
            <Route path="/admin" element={
              <ProtectedRoute adminOnly>
                <PageHeader title="Users" subtitle="Manage platform users and permissions" />
                <AdminPage />
              </ProtectedRoute>
            } />
          </Routes>
        </main>

        <footer>
          <p>Powered by Johns Hopkins Data Science and AI Institute (DSAI)</p>
        </footer>
      </div>
    </div>
  );
}

export default App;
