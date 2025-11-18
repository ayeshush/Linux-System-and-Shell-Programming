#!/bin/bash
# -----------------------------------------------------------
# Shell Script for Load Balancer Setup (setup_lb.sh)
# -----------------------------------------------------------

echo "--- 1. Installing HAProxy and Netcat (Required Tools) ---"
# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (e.g., sudo ./setup_lb.sh)"
    exit 1
fi

# Update package lists and install HAProxy and netcat (for dummy servers)
apt update > /dev/null 2>&1
apt install -y haproxy netcat-openbsd > /dev/null 2>&1

# Check if installation was successful
if [ $? -ne 0 ]; then
    echo "Error installing packages. Exiting."
    exit 1
fi
echo "Packages installed successfully."

# -----------------------------------------------------------
echo "--- 2. Setting up Backend Servers (Ports 8081 and 8082) ---"

# Function to run a dummy web server using netcat in the background
start_dummy_server() {
    PORT=$1
    CONTENT=$2
    # Use 'while true' loop with netcat listening on the port.
    # When a connection comes in, it serves the content and keeps listening (-k).
    echo "Starting dummy server on port $PORT..."
    (
        while true; do
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$CONTENT" | nc -l -p "$PORT" -k
        done
    ) &
    # Store the PID of the background process
    PID=$!
    echo "Server on port $PORT started with PID: $PID"
}

# Kill any previous dummy servers to ensure a clean start
echo "Cleaning up previous dummy servers..."
killall nc -q > /dev/null 2>&1

# Start Server 1 (healthy initially)
start_dummy_server 8081 "Hello from WEB SERVER 01"

# Start Server 2 (healthy initially)
start_dummy_server 8082 "Hello from WEB SERVER 02"

echo "Backend servers are running."
# -----------------------------------------------------------
echo "--- 3. Configuring and Starting HAProxy ---"

# Copy the configuration file to the HAProxy directory
cp haproxy.cfg /etc/haproxy/haproxy.cfg

# Restart HAProxy to load the new configuration
systemctl restart haproxy

# Check HAProxy status
if systemctl is-active --quiet haproxy; then
    echo "HAProxy is running and configured to listen on port 80."
else
    echo "Error: HAProxy failed to start. Check /etc/haproxy/haproxy.cfg for errors."
fi

# -----------------------------------------------------------
echo "--- 4. Testing Instructions ---"
echo "Load Balancer is active on port 80."
echo "Test Round-Robin by running 'curl localhost' multiple times."
echo ""
echo "TEST HEALTH CHECK FAILURE:"
echo "To simulate a failure, stop Server 01: 'kill $(jobs -p | grep 8081)'"
echo "Then, run 'curl localhost'. It should only show output from SERVER 02."
echo ""
echo "CLEANUP:"
echo "To stop everything, run: 'killall nc' and 'systemctl stop haproxy'"
