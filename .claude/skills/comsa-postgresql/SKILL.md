---
name: comsa-postgresql
description: Access and manage the COMSA Dashboard PostgreSQL database. Use this skill when working with the comsa_dashboard database for queries, schema management, or data operations. Handles SSH tunnel for local development and assumes direct access on deployed servers.
---

# COMSA PostgreSQL Database

## Overview

Provides access to the COMSA Dashboard PostgreSQL database with environment-aware connection handling. Automatically manages SSH tunnel connections for local development and assumes direct database access on deployed servers.

## Connection Management

### Environment Detection

Determine the environment to establish the appropriate connection:

**Local Development:**
- Check if SSH tunnel is running on port 5433
- If not running, start tunnel using `scripts/check_tunnel.sh`
- Connect to database via `localhost:5433`

**Deployed Server:**
- Assume direct access to database
- Connect directly using credentials from environment variables

### Quick Connection Check

Before performing database operations, verify the connection:

```bash
# Source environment variables
source .env

# Check if tunnel is needed and running (local only)
./scripts/check_tunnel.sh

# Test connection
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "SELECT 1"
```

## Database Operations

### Running Queries

Execute SQL queries against the database:

```bash
# Simple query
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "SELECT * FROM table_name LIMIT 10"

# Interactive mode
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE
```

### Schema Management

List and manage database schema:

```bash
# List all tables
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "\dt"

# Describe table structure
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "\d table_name"

# List all databases
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -c "\l"
```

### Python Connection

Use the provided Python helper for programmatic access:

```python
from scripts.connect_db import get_db_connection

# Get connection (handles environment detection)
conn = get_db_connection()
cursor = conn.cursor()

# Execute query
cursor.execute("SELECT * FROM table_name")
results = cursor.fetchall()

# Clean up
cursor.close()
conn.close()
```

## Troubleshooting

### SSH Tunnel Issues (Local Development)

If connection fails on local machine:

1. Check if tunnel process is running:
   ```bash
   ps aux | grep "ssh.*5433.*172.23.53.49"
   ```

2. Manually restart tunnel:
   ```bash
   ./scripts/check_tunnel.sh
   ```

3. Verify tunnel connectivity:
   ```bash
   nc -zv localhost 5433
   ```

### Authentication Errors

If authentication fails:

1. Verify `.env` file contains correct credentials
2. Check `PGPASSWORD` environment variable is set
3. Confirm user has access to the database

## Resources

### scripts/

- `check_tunnel.sh` - Checks and starts SSH tunnel for local development
- `connect_db.py` - Python helper for database connections with environment detection

### references/

- `connection_info.md` - Detailed connection information and credentials
- `schema.md` - Database schema documentation (update as schema evolves)
