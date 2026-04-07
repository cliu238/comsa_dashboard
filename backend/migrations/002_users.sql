-- 002_users.sql: User management and job ownership

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    organization VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_role CHECK (role IN ('user', 'admin'))
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

ALTER TABLE jobs ADD COLUMN user_id UUID REFERENCES users(id);
CREATE INDEX idx_jobs_user_id ON jobs(user_id);

COMMENT ON TABLE users IS 'Platform users with authentication credentials';
COMMENT ON COLUMN users.role IS 'User role: user (default) or admin';
COMMENT ON COLUMN jobs.user_id IS 'Owner of the job. NULL for legacy/pre-auth jobs';
