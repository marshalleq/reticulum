#!/bin/sh
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Create group and user with specified IDs
if ! getent group rns >/dev/null 2>&1; then
    addgroup --gid "$PGID" rns
fi

if ! getent passwd rns >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" --uid "$PUID" --ingroup rns --home /config --no-create-home rns
fi

# Ensure directories exist and have correct ownership
mkdir -p /config/storage /logs

# Copy example config if no config exists
if [ ! -f /config/config ]; then
    cp /config-example /config/config
fi

chown -R "$PUID:$PGID" /config /logs

# If /logs is mounted, tee output to a log file and stdout
if mountpoint -q /logs 2>/dev/null; then
    exec gosu rns "$@" 2>&1 | tee /logs/rnsd.log
else
    exec gosu rns "$@"
fi
