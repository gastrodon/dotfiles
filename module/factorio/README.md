# Factorio Server Module

This module configures a Factorio headless multiplayer server on NixOS.

## Features

- Headless server (optimized for servers, no graphics)
- Auto-start on boot via systemd
- UDP port 34197 for game connections
- LAN visibility enabled, public visibility disabled
- Autosave every 10 minutes
- Persistent saves in /var/lib/factorio

## Configuration

Edit `default.nix` to customize:

- `game-name`: Server name
- `port`: Game port (default 34197)
- `game-password`: Set a password for the server
- `admins`: List of Factorio.com usernames for admin access
- `public`: Set to `true` to list on public server browser
- `autosave-interval`: Minutes between autosaves

## Connecting

### From LAN
1. Open Factorio
2. Multiplayer → Browse LAN Games
3. Your server should appear

### From Internet
1. Open Factorio
2. Multiplayer → Connect to Address
3. Enter: `your-server-ip:34197`

## Service Management

```bash
# Check status
systemctl status factorio.service

# View logs
journalctl -u factorio.service -f

# Restart server
sudo systemctl restart factorio.service

# Stop server
sudo systemctl stop factorio.service
```

## Savegame Management

Saves are located in: `/var/lib/factorio/saves/`

```bash
# List saves
sudo ls -lh /var/lib/factorio/saves/

# Backup current save
sudo cp /var/lib/factorio/saves/default.zip ~/factorio-backup.zip
```

## Admin Commands (In-Game)

Press `~` to open console:
- `/help` - List available commands
- `/admins` - List server admins
- `/ban <player>` - Ban a player
- `/kick <player>` - Kick a player
- `/promote <player>` - Make player admin

## Security Notes

- Server is private by default (not listed publicly)
- User verification required (Factorio.com account)
- Consider setting `game-password` for additional security
