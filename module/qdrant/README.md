# Qdrant Module

This module configures Qdrant vector database as a NixOS systemd service.

## Features

- HTTP REST API on port 6333
- gRPC API on port 6334
- Localhost-only access (secure by default)
- Persistent storage in /var/lib/qdrant
- Auto-start on boot via systemd

## Usage

### Health Check

```bash
curl http://localhost:6333/healthz
```

### API Access

```bash
# Welcome message
curl http://localhost:6333

# Create collection
curl -X PUT http://localhost:6333/collections/my_collection \
  -H 'Content-Type: application/json' \
  -d '{"vectors":{"size":4,"distance":"Cosine"}}'

# List collections
curl http://localhost:6333/collections
```

### Service Management

```bash
# Check status
systemctl status qdrant.service

# View logs
journalctl -u qdrant.service -f

# Restart service
sudo systemctl restart qdrant.service
```

## Configuration

Edit `default.nix` to customize:
- Ports (http_port, grpc_port)
- Bind address (host)
- Storage paths
- Performance settings

## Remote Access

By default, Qdrant is bound to localhost only. To enable remote access:

1. Change `host = "0.0.0.0"` in default.nix
2. Uncomment the firewall rules
3. Consider enabling API key authentication
