# Easy Bedrock Server Manager

A single PowerShell script that turns any empty Windows folder into a fully managed Minecraft Bedrock server — no technical knowledge required.

Drop it in a folder, double-click `launch.bat`, and it handles everything else.

---

## Features

- **Zero setup** — downloads and installs the server automatically on first run
- **Auto-updates** — checks for new Minecraft versions daily at a configurable hour, with a 5-minute in-game countdown warning before restarting
- **Auto-restart** — if the server crashes, the manager brings it back up automatically
- **No-IP DDNS** — keeps your dynamic IP updated every 15 minutes so friends can always connect
- **Interactive console** — type any server command directly into the manager window and see the server's responses in real time
- **Config separate from script** — your credentials live in `config.ps1` and never touch version control

---

## Quick Start

1. **Download** the latest release and extract it to an empty folder
2. **Copy** `config.example.ps1` to `config.ps1` and fill in your details
3. **Double-click** `launch.bat`

That's it. The server will download, install, and start automatically.

> **First run note:** Windows may ask you to allow PowerShell to run scripts. The launcher handles this automatically via `-ExecutionPolicy Bypass`.

---

## Configuration

Open `config.ps1` in any text editor:

| Setting | Description |
|---|---|
| `$NoIP_Username` | Your No-IP account email. Leave empty to skip DDNS. |
| `$NoIP_Password` | Your No-IP account password. |
| `$NoIP_Hostname` | Your No-IP hostname, e.g. `myserver.ddns.net` |
| `$UpdateCheckHour` | Hour (0–23) to check for Minecraft updates each day. Default: `2` (2 AM) |

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

Every day at the configured hour, the manager checks the official Minecraft API for a new server version. If one is found:

1. Players receive an in-game warning: *"Server restarting in 5 minutes"*
2. Countdown messages at 4, 3, 2, and 1 minute
3. Server stops, update installs, server restarts
4. Your `server.properties`, `allowlist.json`, and `permissions.json` are preserved automatically

---

## File Layout

```
your-server-folder/
├── Start-BedrockServer.ps1   # The manager script
├── config.ps1                # Your settings (create from config.example.ps1)
├── config.example.ps1        # Settings template
├── launch.bat                # Double-click to start
└── BACKUP/                   # Auto-created — config backups before each update
```

---

## License

MIT — do whatever you want with it.
