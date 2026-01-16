#!/usr/bin/env python3
"""
PostgreSQL database connection helper with environment detection.
Automatically handles SSH tunnel for local development.
"""

import os
import subprocess
import socket
from pathlib import Path

try:
    import psycopg2
except ImportError:
    print("Warning: psycopg2 not installed. Install with: pip install psycopg2-binary")
    psycopg2 = None


def is_port_open(host, port):
    """Check if a port is open on the given host."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(1)
    try:
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False


def ensure_tunnel():
    """Ensure SSH tunnel is running for local development."""
    # Check if we're in local environment (PGHOST=localhost)
    pghost = os.getenv('PGHOST', 'localhost')

    if pghost != 'localhost':
        # Not local, assume direct access
        return True

    # Check if tunnel is running
    if is_port_open('localhost', 5433):
        return True

    # Start tunnel
    print("Starting SSH tunnel...")
    script_dir = Path(__file__).parent
    tunnel_script = script_dir / 'check_tunnel.sh'

    try:
        result = subprocess.run(
            [str(tunnel_script)],
            capture_output=True,
            text=True,
            check=True
        )
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to start tunnel: {e.stderr}")
        return False


def load_env():
    """Load environment variables from .env file."""
    env_path = Path('.env')
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    if '=' in line:
                        key, value = line.split('=', 1)
                        os.environ[key] = value


def get_db_connection():
    """
    Get a database connection with environment detection.

    Returns:
        psycopg2.connection: Database connection object

    Raises:
        ImportError: If psycopg2 is not installed
        Exception: If connection fails
    """
    if psycopg2 is None:
        raise ImportError("psycopg2 is not installed. Install with: pip install psycopg2-binary")

    # Load environment variables
    load_env()

    # Ensure tunnel is running for local development
    if not ensure_tunnel():
        raise Exception("Failed to establish SSH tunnel")

    # Get connection parameters from environment
    conn_params = {
        'host': os.getenv('PGHOST', 'localhost'),
        'port': int(os.getenv('PGPORT', '5433')),
        'user': os.getenv('PGUSER', 'eric'),
        'password': os.getenv('PGPASSWORD'),
        'database': os.getenv('PGDATABASE', 'comsa_dashboard')
    }

    # Create connection
    try:
        conn = psycopg2.connect(**conn_params)
        return conn
    except Exception as e:
        raise Exception(f"Failed to connect to database: {e}")


def test_connection():
    """Test database connection."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"✓ Connected to: {version[0]}")

        cursor.execute("SELECT current_database(), current_user;")
        db_info = cursor.fetchone()
        print(f"✓ Database: {db_info[0]}, User: {db_info[1]}")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        return False


if __name__ == "__main__":
    # Test connection when run directly
    test_connection()
