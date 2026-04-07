import { useState, useEffect } from 'react';
import { fetchAdminUsers, updateAdminUser } from '../api/client';

export default function AdminPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadUsers = async () => {
    try {
      const data = await fetchAdminUsers();
      setUsers(data.users || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadUsers(); }, []);

  const toggleActive = async (userId, currentActive) => {
    await updateAdminUser(userId, { is_active: !currentActive });
    loadUsers();
  };

  const toggleRole = async (userId, currentRole) => {
    const newRole = currentRole === 'admin' ? 'user' : 'admin';
    await updateAdminUser(userId, { role: newRole });
    loadUsers();
  };

  if (loading) return <div>Loading users...</div>;
  if (error) return <div className="auth-error">{error}</div>;

  return (
    <div className="admin-page">
      <h2>User Management</h2>
      <table className="admin-table">
        <thead>
          <tr>
            <th>Email</th>
            <th>Name</th>
            <th>Organization</th>
            <th>Role</th>
            <th>Jobs</th>
            <th>Active</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.id}>
              <td>{u.email}</td>
              <td>{u.name || '-'}</td>
              <td>{u.organization || '-'}</td>
              <td>{u.role}</td>
              <td>{u.job_count}</td>
              <td>{u.is_active ? 'Yes' : 'No'}</td>
              <td>
                <button onClick={() => toggleActive(u.id, u.is_active)} className="admin-btn">
                  {u.is_active ? 'Disable' : 'Enable'}
                </button>
                <button onClick={() => toggleRole(u.id, u.role)} className="admin-btn">
                  {u.role === 'admin' ? 'Demote' : 'Promote'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
