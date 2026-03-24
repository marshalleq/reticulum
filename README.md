# Reticulum Docker

Docker image for the Reticulum Network Stack. Includes `rnsd`, `nomadnet`, and `lxmd`. Builds for both `linux/amd64` and `linux/arm64`.

## Quick start

```bash
docker run -d \
  --name reticulum \
  -v /path/to/your/config:/config \
  -v /path/to/your/logs:/logs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Pacific/Auckland \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ghcr.io/marshalleq/reticulum:main
```

## Included applications

This image bundles several Reticulum applications. By default it runs `rnsd`, but you can run any of them by appending the command after the image name:

| Command | Description |
|---------|-------------|
| `rnsd --config /config` | Reticulum network daemon (default) |
| `nomadnet` | Nomad Network — encrypted, resilient mesh communications with a terminal UI |
| `lxmd` | LXMF daemon — store-and-forward message propagation |
| `rnstatus --config /config` | Show status of connected interfaces |
| `rnpath --config /config <destination>` | Look up a path to a destination |
| `rnprobe --config /config <destination>` | Probe a destination and show latency |

### Running a specific application

To run something other than `rnsd`, put the command after the image name:

```bash
# Run Nomad Network
docker run -d \
  --name nomadnet \
  -v /path/to/config:/config \
  -v /path/to/logs:/logs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Pacific/Auckland \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ghcr.io/marshalleq/reticulum:main \
  nomadnet

# Run LXMF propagation daemon
docker run -d \
  --name lxmd \
  -v /path/to/config:/config \
  -v /path/to/logs:/logs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Pacific/Auckland \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ghcr.io/marshalleq/reticulum:main \
  lxmd

# Run a one-off diagnostic command
docker run --rm \
  -v /path/to/config:/config \
  ghcr.io/marshalleq/reticulum:main \
  rnstatus --config /config
```

If no command is specified, the container runs `rnsd --config /config`.

## Configuration

### Volume mount

| Mount | Description |
|-------|-------------|
| `/config` | Reticulum configuration directory. Must contain a `config` file. Storage (keys, caches) is also written here. |
| `/logs` | Optional. If mounted, rnsd output is written to `/logs/rnsd.log` as well as stdout. |

Copy `config-example` to your host config directory as `config` and edit to suit your setup:

```bash
mkdir -p /path/to/config
cp config-example /path/to/config/config
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID that rnsd runs as inside the container |
| `PGID` | `1000` | Group ID that rnsd runs as inside the container |
| `RNS_LOGLEVEL` | `4` | Log level (0=critical, 7=verbose) |
| `TZ` | `UTC` | Timezone for log timestamps (e.g. `Pacific/Auckland`, `Australia/Sydney`) |

### Logging

Reticulum logs to stdout, so log rotation is handled by Docker. By default Docker keeps logs forever. Set limits per container:

| Option | Recommended | Description |
|--------|-------------|-------------|
| `--log-opt max-size` | `10m` | Maximum size of each log file |
| `--log-opt max-file` | `3` | Number of rotated log files to keep |

Or set defaults globally in `/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### Port mapping

Map ports based on which interfaces you enable in your config:

| Port | Protocol | Description |
|------|----------|-------------|
| `37428` | TCP | Reticulum shared instance port (for local clients to connect to this daemon) |
| `4242` | TCP | Default TCP server interface port (only needed if you enable `TCPServerInterface`) |

Example with TCP server enabled:

```bash
docker run -d \
  --name reticulum \
  -v /path/to/config:/config \
  -v /path/to/logs:/logs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Pacific/Auckland \
  -p 37428:37428 \
  -p 4242:4242 \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ghcr.io/marshalleq/reticulum:main
```

### User/group mapping

The `PUID` and `PGID` variables control the UID and GID of the `rns` user inside the container. Set these to match the owner of your host config directory so that file permissions work correctly.

Find your UID and GID:

```bash
id -u  # your UID
id -g  # your GID
```

On TrueNAS, if your dataset is owned by a specific user (e.g. `apps` with UID 568), set:

```bash
-e PUID=568 -e PGID=568
```

### Network mode

If your RNode is on the same LAN (connected via WiFi using `port = tcp://...` in the config), the container needs access to your local network. Use host networking:

```bash
docker run -d \
  --name reticulum \
  --network host \
  -v /path/to/config:/config \
  -v /path/to/logs:/logs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Pacific/Auckland \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ghcr.io/marshalleq/reticulum:main
```

With `--network host`, port mapping flags (`-p`) are not needed — all ports are directly accessible.

## Building locally

```bash
docker build -t reticulum .
```

Multi-arch build:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t reticulum .
```

## GitHub Actions

The included workflow at `.github/workflows/build.yml` automatically builds and pushes multi-arch images to GitHub Container Registry on pushes to `main` and on version tags (`v*`). A scheduled weekly rebuild (Monday 04:00 UTC) keeps the base image and packages up to date.

To use it:
1. Push this directory as its own GitHub repository
2. Ensure GitHub Actions has permission to push to GHCR (Settings > Actions > General > Workflow permissions > Read and write)
3. Push a commit or tag to trigger the build

## Examples

LoRa-only relay (no internet exposure):

```bash
docker run -d \
  --name reticulum \
  --network host \
  -v ./config:/config \
  -v ./logs:/logs \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Pacific/Auckland \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --restart unless-stopped \
  reticulum
```

With a config containing only an RNode interface and `enable_transport = True`, this acts as a LoRa relay — forwarding packets between LoRa nodes without touching the internet.
