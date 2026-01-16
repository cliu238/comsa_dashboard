#!/bin/bash
# Check if SSH tunnel is running, start if needed

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if running on local machine (check if localhost:5433 is being used)
if [ "$PGHOST" != "localhost" ]; then
    echo "Not on local machine, assuming direct database access"
    exit 0
fi

# Check if tunnel is already running
if nc -z localhost 5433 2>/dev/null; then
    echo "✓ SSH tunnel is running on port 5433"
    exit 0
fi

echo "SSH tunnel not detected, starting..."

# Check if expect is available
if ! command -v expect &> /dev/null; then
    echo "Error: expect is not installed. Please install it first."
    exit 1
fi

# Create temporary expect script
cat > /tmp/ssh_tunnel_$$.exp << 'EXPEOF'
#!/usr/bin/expect -f
set timeout -1
spawn ssh -o StrictHostKeyChecking=no -L 5433:172.23.53.49:5432 -N cliu238@dslogin01.pha.jhu.edu
expect "password:"
send "$env(SSH_PASSWORD)\r"
expect eof
EXPEOF

chmod +x /tmp/ssh_tunnel_$$.exp

# Start tunnel in background
/tmp/ssh_tunnel_$$.exp &
TUNNEL_PID=$!

# Wait for tunnel to establish
sleep 3

# Verify tunnel is running
if nc -z localhost 5433 2>/dev/null; then
    echo "✓ SSH tunnel started successfully (PID: $TUNNEL_PID)"
    rm /tmp/ssh_tunnel_$$.exp
    exit 0
else
    echo "✗ Failed to start SSH tunnel"
    rm /tmp/ssh_tunnel_$$.exp
    exit 1
fi
