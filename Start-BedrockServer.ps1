# ============================================================
# MINECRAFT BEDROCK SERVER MANAGER v2.0
# ============================================================
# Drop this script in any empty folder and run it.
# It will download, install, and run the server automatically.
#
# Features:
#   - Works from a blank folder (auto-installs server)
#   - Updates No-IP DDNS on startup
#   - Checks for MC updates daily at the configured hour
#   - Sends 5-minute in-game countdown before updating
#   - Auto-restarts server if it crashes
# ============================================================

$ScriptVersion = "1.1.0"

# ==========================
#       CONFIGURATION
# ==========================

$configPath = "$PSScriptRoot\config.ps1"
if (!(Test-Path $configPath)) {
    Write-Host "ERROR: config.ps1 not found." -ForegroundColor Red
    Write-Host "Copy config.example.ps1 to config.ps1 and fill in your details." -ForegroundColor Yellow
    Start-Sleep 10
    exit 1
}
. $configPath

# ==========================

$gameDir = $PSScriptRoot
Set-Location $gameDir
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log($msg, $color = "White") {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] $msg" -ForegroundColor $color
}

function Update-NoIP {
    if (-not $NoIP_Username) {
        Write-Log "No-IP not configured  -  skipping DDNS update." "Gray"
        return
    }
    try {
        $publicIP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
    } catch {
        Write-Log "ERROR: Could not determine public IP: $_" "Red"
        return
    }
    Write-Log "Updating No-IP DDNS ($NoIP_Hostname) with IP $publicIP..." "Yellow"
    try {
        $pair   = "${NoIP_Username}:${NoIP_Password}"
        $b64    = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $hdrs   = @{ Authorization = "Basic $b64"; "User-Agent" = "MCServerManager/2.0 $NoIP_Username" }
        $resp   = Invoke-WebRequest -Uri "https://dynupdate.no-ip.com/nic/update?hostname=$NoIP_Hostname&myip=$publicIP" `
                                    -Headers $hdrs -UseBasicParsing
        Write-Log "No-IP response: $($resp.Content)" "Green"
    } catch {
        Write-Log "ERROR updating No-IP: $_" "Red"
    }
}

function Get-LatestInfo {
    try {
        $resp   = Invoke-WebRequest -Uri "https://net-secondary.web.minecraft-services.net/api/v1.0/download/links" -UseBasicParsing
        $links  = ($resp.Content | ConvertFrom-Json).result.links
        $url    = ($links | Where-Object { $_.downloadType -eq "serverBedrockWindows" }).downloadUrl
        if (-not $url) { throw "URL not found in API response" }
        return @{ Url = $url; Filename = $url.Split('/')[-1] }
    } catch {
        Write-Log "ERROR: Could not reach Minecraft download API: $_" "Red"
        return $null
    }
}

function Get-InstalledVersion {
    $f = "$gameDir\current_version.txt"
    if (Test-Path $f) { return (Get-Content $f).Trim() }
    return ""
}

function Install-ServerUpdate($info) {
    $zipPath = "$gameDir\BACKUP\$($info.Filename)"

    if (!(Test-Path "$gameDir\BACKUP")) {
        New-Item -ItemType Directory -Path "$gameDir\BACKUP" | Out-Null
    }

    # Back up user config before overwriting
    foreach ($file in @("server.properties", "allowlist.json", "permissions.json")) {
        if (Test-Path "$gameDir\$file") {
            Write-Log "Backing up $file..." "Gray"
            Copy-Item "$gameDir\$file" "$gameDir\BACKUP" -Force
        }
    }

    Write-Log "Downloading $($info.Filename)..." "Yellow"
    try {
        Invoke-WebRequest -Uri $info.Url -OutFile $zipPath
    } catch {
        Write-Log "ERROR: Download failed: $_" "Red"
        return $false
    }

    Write-Log "Extracting server files..." "Yellow"
    try {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $gameDir -Force
    } catch {
        Write-Log "ERROR: Extraction failed: $_" "Red"
        return $false
    }

    # Restore user config (overwrites defaults from zip)
    foreach ($file in @("server.properties", "allowlist.json", "permissions.json")) {
        $backup = "$gameDir\BACKUP\$file"
        if (Test-Path $backup) {
            Write-Log "Restoring $file..." "Gray"
            Copy-Item $backup "$gameDir" -Force
        }
    }

    Set-Content "$gameDir\current_version.txt" $info.Filename
    Write-Log "Installed: $($info.Filename)" "Green"
    return $true
}

function Start-MCServer {
    Write-Log "Starting bedrock_server.exe..." "Green"
    $pinfo                       = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName              = "$gameDir\bedrock_server.exe"
    $pinfo.WorkingDirectory      = $gameDir
    $pinfo.RedirectStandardInput = $true
    $pinfo.UseShellExecute       = $false
    $proc                        = New-Object System.Diagnostics.Process
    $proc.StartInfo              = $pinfo
    $proc.Start() | Out-Null
    Write-Log "Server running (PID $($proc.Id))." "Green"
    return $proc
}

function Send-Command($proc, $cmd) {
    try {
        $proc.StandardInput.WriteLine($cmd)
        $proc.StandardInput.Flush()
    } catch {
        Write-Log "Warning: Could not send command '$cmd': $_" "Yellow"
    }
}

function Stop-MCServer($proc) {
    Write-Log "Sending stop command..." "Yellow"
    Send-Command $proc "stop"
    if (!$proc.WaitForExit(30000)) {
        Write-Log "Server did not stop gracefully  -  killing process." "Red"
        $proc.Kill()
    }
}

function Update-Script($proc) {
    if (-not $ScriptAutoUpdate) { return }
    Write-Log "Checking for script updates..." "Yellow"
    try {
        $resp   = Invoke-WebRequest -Uri "https://api.github.com/repos/jhwblender/easy-bedrock-server-manager/releases/latest" -UseBasicParsing
        $latest = ($resp.Content | ConvertFrom-Json).tag_name -replace '^v', ''
    } catch {
        Write-Log "Could not check for script updates: $_" "Gray"
        return
    }

    if ([Version]$latest -le [Version]$ScriptVersion) {
        Write-Log "Script is up to date (v$ScriptVersion)." "Green"
        return
    }

    Write-Log "Script update available: v$latest (current: v$ScriptVersion)" "Cyan"
    $url      = "https://raw.githubusercontent.com/jhwblender/easy-bedrock-server-manager/v$latest/Start-BedrockServer.ps1"
    $tempPath = "$gameDir\_Update-BedrockServer.ps1"

    try {
        Invoke-WebRequest -Uri $url -OutFile $tempPath -UseBasicParsing
    } catch {
        Write-Log "ERROR: Failed to download script update: $_" "Red"
        return
    }

    if ($proc -and !$proc.HasExited) {
        Send-Command $proc "say [SERVER] Server manager is updating. Restarting in 30 seconds."
        Start-Sleep -Seconds 30
        Stop-MCServer $proc
    }

    Copy-Item $tempPath "$gameDir\Start-BedrockServer.ps1" -Force
    Remove-Item $tempPath
    Write-Log "Script updated to v$latest. Relaunching..." "Cyan"
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$gameDir\Start-BedrockServer.ps1`""
    exit
}

# ============================================================
#  STARTUP
# ============================================================

Write-Host ""
Write-Host "  MINECRAFT BEDROCK SERVER MANAGER v2.0" -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""

Update-NoIP

Write-Log "Checking for latest Minecraft Bedrock version..." "Yellow"
$latest = Get-LatestInfo

if (-not $latest) {
    Write-Log "Cannot reach update server. Attempting to start existing installation." "Yellow"
} else {
    $installed = Get-InstalledVersion
    if ($installed -eq $latest.Filename) {
        Write-Log "Already on latest version: $($latest.Filename)" "Green"
    } else {
        if ($installed) {
            Write-Log "Update available: $($latest.Filename)  (was: $installed)" "Green"
        } else {
            Write-Log "No installation found  -  performing first-time setup..." "Cyan"
        }
        Install-ServerUpdate $latest
    }
}

if (!(Test-Path "$gameDir\bedrock_server.exe")) {
    Write-Log "FATAL: bedrock_server.exe not found. Check errors above." "Red"
    Start-Sleep 10
    exit 1
}

$serverProc        = Start-MCServer
$lastCheckDate     = ""
$lastCrashTime     = $null
$crashCooldownSec  = 60   # wait at least 60 s before restarting after a crash
$noIPIntervalMin   = 15
$lastNoIPUpdate    = Get-Date  # already updated at startup

Write-Log "Manager running. Update check scheduled at $($UpdateCheckHour):00 each day. No-IP refresh every $noIPIntervalMin min. Press Ctrl+C to exit." "Cyan"
Write-Log "Type any Minecraft server command and press Enter to send it." "Cyan"

function Wait-OrInput($proc, $seconds) {
    [Console]::Write(">> ")
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        if ([Console]::KeyAvailable) {
            $line = [Console]::ReadLine()
            if ($line -and $proc -and !$proc.HasExited) {
                Send-Command $proc $line
                Write-Log "Sent: $line" "Cyan"
                Start-Sleep -Milliseconds 400
            }
            [Console]::Write(">> ")
        }
        Start-Sleep -Milliseconds 100
    }
}

# ============================================================
#  MAIN LOOP
# ============================================================

while ($true) {
    Wait-OrInput $serverProc 30

    # -- Auto-restart on crash ------------------------------
    if ($serverProc.HasExited) {
        $now = Get-Date
        if ($lastCrashTime -and (($now - $lastCrashTime).TotalSeconds -lt $crashCooldownSec)) {
            Write-Log "Server exited again quickly  -  waiting before restart." "Yellow"
            Start-Sleep -Seconds $crashCooldownSec
        }
        Write-Log "Server is not running  -  restarting..." "Yellow"
        $lastCrashTime = Get-Date
        $serverProc    = Start-MCServer
        continue
    }

    # -- Periodic No-IP refresh ----------------------------
    if (((Get-Date) - $lastNoIPUpdate).TotalMinutes -ge $noIPIntervalMin) {
        Update-NoIP
        $lastNoIPUpdate = Get-Date
    }

    # -- Daily update check --------------------------------
    $now      = Get-Date
    $dateKey  = $now.ToString("yyyyMMdd")

    if ($now.Hour -eq $UpdateCheckHour -and $lastCheckDate -ne $dateKey) {
        $lastCheckDate = $dateKey
        Write-Log "Running scheduled update check..." "Yellow"

        Update-Script $serverProc

        $latest = Get-LatestInfo
        if ($latest) {
            $installed = Get-InstalledVersion
            if ($installed -ne $latest.Filename) {
                Write-Log "New version found: $($latest.Filename)" "Green"

                # 5-minute in-game countdown
                Send-Command $serverProc "say [SERVER] A Minecraft update is available. Restarting in 5 minutes."
                Start-Sleep -Seconds 60
                Send-Command $serverProc "say [SERVER] Restarting in 4 minutes."
                Start-Sleep -Seconds 60
                Send-Command $serverProc "say [SERVER] Restarting in 3 minutes."
                Start-Sleep -Seconds 60
                Send-Command $serverProc "say [SERVER] Restarting in 2 minutes. Please finish up and disconnect."
                Start-Sleep -Seconds 60
                Send-Command $serverProc "say [SERVER] Restarting in 1 minute!"
                Start-Sleep -Seconds 60
                Send-Command $serverProc "say [SERVER] Shutting down now. Back in a moment!"
                Start-Sleep -Seconds 3

                Stop-MCServer $serverProc

                $ok = Install-ServerUpdate $latest
                if (-not $ok) {
                    Write-Log "Update failed  -  restarting on previous version." "Red"
                }

                # Refresh DDNS after overnight IP changes
                Update-NoIP

                $serverProc    = Start-MCServer
                $lastCrashTime = $null
            } else {
                Write-Log "Server is already on the latest version ($installed)." "Green"
            }
        }
    }
}
