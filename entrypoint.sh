#!/bin/bash
set -e

# Make sure all the needed directories exist and have right permissions
mkdir -p /config/.cache/openbox/sessions
chown -R 1000:1000 /config

# Start the default s6 init process that comes with the base image
# This will handle starting nginx, openbox, etc.
exec /init &

# Wait a bit for services to start
sleep 5

# Start mt5linux as non-root user
echo "Starting mt5linux server..."
su abc -c "mt5linux --host 0.0.0.0 --port 8001" 