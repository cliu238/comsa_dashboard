# COMSA Dashboard PostgreSQL Connection Information

## Environment Variables

The database connection uses the following environment variables from `.env`:

```bash
# PostgreSQL credentials (via SSH tunnel)
PGPASSWORD=ChangeMeNow1234
PGHOST=localhost                # localhost for local dev, direct IP for server
PGPORT=5433                     # 5433 for local tunnel, 5432 for direct
PGUSER=eric
PGDATABASE=comsa_dashboard

# Direct PostgreSQL host (requires SSH tunnel)
PG_REMOTE_HOST=172.23.53.49
PG_REMOTE_PORT=5432

# SSH credentials for JHU server (tunnel gateway)
SSH_HOST=dslogin01.pha.jhu.edu
SSH_USER=cliu238
SSH_PASSWORD=Baza7183!
```

## Connection Architecture

### Local Development

```
Your Machine → SSH Tunnel → JHU Server → PostgreSQL Server
             (port 5433)                  (172.23.53.49:5432)
```

**SSH Tunnel Command:**
```bash
ssh -L 5433:172.23.53.49:5432 -N cliu238@dslogin01.pha.jhu.edu
```

**PostgreSQL Connection:**
```bash
psql -h localhost -p 5433 -U eric -d comsa_dashboard
```

### Deployed Server

Assumes direct network access to PostgreSQL server:

```
Deployed Server → PostgreSQL Server
                 (172.23.53.49:5432)
```

**PostgreSQL Connection:**
```bash
psql -h 172.23.53.49 -p 5432 -U eric -d comsa_dashboard
```

## Available Databases

The PostgreSQL server hosts multiple databases:

- `comsa_dashboard` - Main application database (use this)
- `astromodels_eric` - Owned by eric
- `postgres` - Default system database
- `realtime` - Real-time data
- `sciserver` - SciServer integration
- `sciserver_docs` - SciServer documentation
- Others...

## Common Connection Patterns

### Bash Scripts

```bash
#!/bin/bash
source .env

# Ensure tunnel is running (local only)
./scripts/check_tunnel.sh

# Execute query
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE << EOF
SELECT * FROM my_table;
EOF
```

### Python Scripts

```python
from scripts.connect_db import get_db_connection

# Get connection (handles tunnel automatically)
conn = get_db_connection()
cursor = conn.cursor()

# Execute query
cursor.execute("SELECT * FROM my_table")
results = cursor.fetchall()

# Clean up
cursor.close()
conn.close()
```

### R Scripts (for backend)

```r
library(RPostgres)

# Load environment variables
readRenviron(".env")

# Create connection
con <- dbConnect(
  Postgres(),
  host = Sys.getenv("PGHOST"),
  port = as.integer(Sys.getenv("PGPORT")),
  user = Sys.getenv("PGUSER"),
  password = Sys.getenv("PGPASSWORD"),
  dbname = Sys.getenv("PGDATABASE")
)

# Execute query
result <- dbGetQuery(con, "SELECT * FROM my_table")

# Clean up
dbDisconnect(con)
```

## Security Notes

1. **Never commit `.env` file** - It contains sensitive credentials
2. **SSH tunnel runs in background** - Use `ps aux | grep ssh` to check status
3. **Password in environment** - Be cautious with shell history
4. **Server deployment** - Ensure `.env` is properly secured on deployed servers
