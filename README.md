# Easy Bedrock Server Manager

A single PowerShell script that turns any empty Windows folder into a fully managed Minecraft Bedrock server — no technical knowledge required.

Drop it in a folder, double-click `launch.bat`, and it handles everything else.

---

## Features

- **Zero setup** — downloads and installs the server automatically on first run
- **First-run wizard** — no config file needed; the manager asks for your settings on first launch and creates it for you
- **Hot-reload config** — edit `config.ps1` while the server is running and changes apply within 30 seconds, no restart needed
- **Auto-updates** — checks for new Minecraft versions daily at a configurable hour, with a 5-minute in-game countdown warning before restarting
- **Self-updating** — the manager updates itself from GitHub on the same nightly schedule
- **Auto-restart** — if the server crashes, the manager brings it back up automatically
- **No-IP DDNS** — keeps your dynamic IP updated every 15 minutes so friends can always connect
- **Interactive console** — type any server command directly into the manager window and see the server's responses in real time

---

## Quick Start

1. **Download** the latest release and extract it to an empty folder
2. **Double-click** `launch.bat`
3. Answer the setup questions on first run

That's it. The manager creates your config, then downloads, installs, and starts the server automatically.

> **Note:** Windows may ask you to allow PowerShell to run scripts. The launcher handles this automatically via `-ExecutionPolicy Bypass`.

---

## Configuration

`config.ps1` is created automatically on first run. You can edit it at any time — changes are picked up within 30 seconds without restarting.

| Setting | Description |
|---|---|
| `$NoIP_Username` | Your No-IP account email. Leave empty to skip DDNS. |
| `$NoIP_Password` | Your No-IP account password. |
| `$NoIP_Hostname` | Your No-IP hostname, e.g. `myserver.ddns.net` |
| `$UpdateCheckHour` | Hour (0–23) to check for Minecraft and script updates each day. Default: `2` (2 AM) |
| `$ScriptAutoUpdate` | `$true` / `$false` — auto-update the manager itself from GitHub. Default: `$true` |

No-IP is completely optional — if you leave `$NoIP_Username` empty the manager skips all DDNS updates.

---

## Console Commands

While the server is running, the manager window accepts commands directly:

```
>> list
>> say Server restarting in 5 minutes!
>> time set day
>> op PlayerName
```

Type any standard [Bedrock server command](https://wiki.bedrock.dev/commands/commands.html) and press Enter.

---

## Requirements

- Windows 10 / 11
- PowerShell 5.1 (included with Windows — no install needed)
- Internet connection (for initial download and updates)

---

## How Updates Work

Every day at the configured hour, the manager runs two checks:

**Script update** — checks GitHub for a newer release. If found, warns players, restarts in 30 seconds, and relaunches on the new version.

**Minecraft update** — checks the official Minecraft API for a new server version. If found:

1. Players receive an in-game warning: *"Server restarting in 5 minutes"*
2. Countdown messages at 4, 3, 2, and 1 minute
3. Server stops, update installs, server restarts
4. Your `server.properties`, `allowlist.json`, and `permissions.json` are preserved automatically

---

## File Layout

```
your-server-folder/
├── Start-BedrockServer.ps1   # The manager script
├── config.ps1                # Your settings (auto-created on first run)
├── config.example.ps1        # Settings template for reference
├── launch.bat                # Double-click to start
└── BACKUP/                   # Auto-created — config backups before each update
```

---

## License

MIT — do whatever you want with it.
