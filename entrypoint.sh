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

# rnsd with -s flag logs to /config/logfile instead of stdout.
# We run it in the background and tail the logfile to stdout so
# docker logs works. Also copy to /logs if mounted.
if [ "$1" = "rnsd" ]; then
    # Start rnsd as a service (stays running, logs to file)
    gosu rns "$@" -s &
    RNSD_PID=$!

    # Wait for logfile to appear
    while [ ! -f /config/logfile ]; do sleep 0.2; done

    # Tail logfile to stdout, and to /logs if mounted
    if mountpoint -q /logs 2>/dev/null; then
        tail -f /config/logfile | tee /logs/rnsd.log &
    else
        tail -f /config/logfile &
    fi
    TAIL_PID=$!

    # Forward signals to rnsd
    trap "kill $RNSD_PID; kill $TAIL_PID; wait $RNSD_PID 2>/dev/null" TERM INT
    wait $RNSD_PID
    kill $TAIL_PID 2>/dev/null
else
    # For other commands (nomadnet, lxmd, etc), run directly
    if mountpoint -q /logs 2>/dev/null; then
        exec gosu rns "$@" 2>&1 | tee /logs/rnsd.log
    else
        exec gosu rns "$@"
    fi
fi
