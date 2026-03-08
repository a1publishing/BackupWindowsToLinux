# BackupWindowsToLinux

A PowerShell module for backing up files from Windows to remote Linux systems using **native OpenSSH**. Only transfers new or modified files for efficient incremental backups.

## Features

- **Incremental backups** — Only transfers new or modified files (compares size + timestamp)
- **Native OpenSSH** — Uses Windows 10+ built-in SSH (no third-party modules needed)
- **SSH key authentication** — Secure, password-less backups
- **Exclusion patterns** — Skip files and directories by pattern (e.g., `node_modules`, `.git`, `*.tmp`)
- **Orphaned cleanup** — Optionally delete files/directories on remote that no longer exist locally
- **Dry run mode** — Preview changes without transferring
- **Progress tracking** — Real-time progress display
- **Timestamp preservation** — Maintains original file modification times

## Prerequisites

**Windows OpenSSH Client** — Already installed on Windows 10/11 and Server 2019+

To verify:
```powershell
ssh -V
```

If not installed:
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

## Installation

### From PowerShell Gallery
```powershell
Install-Module BackupWindowsToLinux
```

### Manual
Copy the module folder to a directory in your `$env:PSModulePath`.

## Quick Start

### 1. Set Up SSH Keys (One-time)

```powershell
# Generate key
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519" -C "backup@mypc"

# Copy to server
type "$env:USERPROFILE\.ssh\id_ed25519.pub" | ssh admin@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# Test
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" admin@192.168.1.100
```

### 2. Run Backup

```powershell
Import-Module BackupWindowsToLinux

Sync-ToLinux `
    -Source "C:\Documents" `
    -Destination "/backup/documents" `
    -HostName "192.168.1.100" `
    -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_ed25519"
```

## Usage Examples

### Basic Backup
```powershell
Sync-ToLinux `
    -Source "C:\Data" `
    -Destination "/backup/data" `
    -HostName "myserver.com" `
    -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
```

### Exclude Directories/Files
```powershell
Sync-ToLinux `
    -Source "C:\Projects" `
    -Destination "/backup/projects" `
    -HostName "server.com" `
    -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa" `
    -ExcludePatterns @("node_modules", ".git", "bin", "obj", "*.tmp")
```

### Dry Run (Preview)
```powershell
Sync-ToLinux `
    -Source "C:\Data" `
    -Destination "/backup" `
    -HostName "192.168.1.100" `
    -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa" `
    -DryRun
```

### Mirror Mode (Delete Orphans)
```powershell
Sync-ToLinux `
    -Source "C:\Sync" `
    -Destination "/home/user/sync" `
    -HostName "nas.local" `
    -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa" `
    -DeleteOrphaned
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Source` | Yes | Local Windows path to backup |
| `Destination` | Yes | Remote Linux destination path |
| `HostName` | Yes | Remote server hostname or IP |
| `UserName` | Yes | SSH username |
| `KeyFile` | No | Path to SSH private key (recommended) |
| `Port` | No | SSH port (default: 22) |
| `ExcludePatterns` | No | Array of patterns to exclude |
| `DryRun` | No | Preview mode — don't transfer |
| `DeleteOrphaned` | No | Delete remote files/dirs not in source |
| `Verbose` | No | Show detailed progress |

## Exclusion Patterns

| Pattern | Excludes |
|---------|----------|
| `*.tmp` | All .tmp files |
| `node_modules` | node_modules directory + contents |
| `.git` | .git directory + contents |
| `bin` | bin directory + contents |
| `*.log` | All .log files |

**Common examples:**
```powershell
# Development
-ExcludePatterns @("node_modules", ".git", "bin", "obj", "*.tmp", ".vs")

# General
-ExcludePatterns @("Temp", "Cache", "*.tmp", "*.bak", "Thumbs.db")
```

## Automated Backups

Create `C:\Scripts\DailyBackup.ps1`:

```powershell
$logFile = "C:\Logs\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $logFile

try {
    Import-Module BackupWindowsToLinux

    Sync-ToLinux `
        -Source "C:\Data" `
        -Destination "/backup/data" `
        -HostName "backup-server.local" `
        -UserName "backupuser" `
        -KeyFile "$env:USERPROFILE\.ssh\backup_key" `
        -Verbose

    Write-Host "Backup completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Backup failed: $_"
}
finally {
    Stop-Transcript
}
```

**Schedule it:**
```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\Scripts\DailyBackup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -TaskName "Daily Linux Backup" -Action $action -Trigger $trigger
```

## How It Works

1. Connects to remote via SSH
2. Scans local files recursively
3. Builds remote file index (path, size, timestamp)
4. Compares each file (size + timestamp with 2s tolerance)
5. Transfers only changed files via SCP
6. Preserves modification timestamps
7. Optionally deletes orphaned files/directories

## Troubleshooting

**"OpenSSH client not found"**
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

**"SSH connection failed"**
- Verify: `ping 192.168.1.100`
- Test SSH: `ssh -i "keyfile" user@host`
- Check firewall allows port 22

**"Permission denied (publickey)"**
```bash
# On Linux server:
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**Files always transfer**
- Check clock sync (both systems should use NTP)
- Verify filesystems preserve timestamps

## Security Best Practices

1. Use SSH keys (never passwords for automated backups)
2. Protect private keys with passphrases
3. Use dedicated backup user with minimal permissions
4. Rotate SSH keys annually
5. Keep audit logs of backup operations
6. Restrict SSH access by IP in firewall

## License

MIT — see [LICENSE](LICENSE)
