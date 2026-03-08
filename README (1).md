# BackupToLinux PowerShell Module

A PowerShell module for backing up files from Windows to remote Linux systems via SSH/SFTP. Supports both **native Windows OpenSSH** (recommended) and **Posh-SSH module**. Only transfers new or modified files for efficient incremental backups.

## Features

- ✅ **Incremental backups** - Only transfers new or modified files
- ✅ **Dual SSH support** - Native OpenSSH (Windows 10+) OR Posh-SSH module
- ✅ **Multiple authentication methods** - SSH keys (recommended), passwords, or credentials
- ✅ **Exclusion patterns** - Skip files matching specific patterns
- ✅ **Dry run mode** - Preview what would be transferred
- ✅ **Orphaned file deletion** - Optionally remove files on remote that no longer exist locally
- ✅ **Progress tracking** - Real-time progress display
- ✅ **Timestamp preservation** - Maintains original file modification times

## Why OpenSSH is Recommended

**Native Windows OpenSSH** (built into Windows 10/11 and Server 2019+):
- ✅ No installation required
- ✅ Better performance
- ✅ More secure (native OS integration)
- ✅ Standard SSH key management
- ⚠️ Requires SSH key authentication (no password support from PowerShell)

**Posh-SSH Module** (alternative):
- ✅ Supports password authentication
- ✅ PowerShell credential objects
- ⚠️ Requires separate installation
- ⚠️ Slightly slower for large transfers

## Prerequisites

### Option 1: OpenSSH (Recommended)

**Windows 10/11:**
1. Open Settings > Apps > Optional Features
2. Add "OpenSSH Client" if not already installed
3. Or via PowerShell (as Administrator):
   ```powershell
   Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
   ```

**Verify installation:**
```powershell
ssh -V
```

### Option 2: Posh-SSH Module

```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser
```

## Installation

### Quick Install

1. Download `BackupToLinux.psm1`
2. Place in your PowerShell modules directory:
   ```powershell
   $modulePath = "$HOME\Documents\WindowsPowerShell\Modules\BackupToLinux"
   New-Item -Path $modulePath -ItemType Directory -Force
   Copy-Item BackupToLinux.psm1 -Destination $modulePath
   ```

### Or Use From Current Directory

```powershell
Import-Module .\BackupToLinux.psm1
```

## Quick Start Guide

### Step 1: Set Up SSH Keys (One-time, OpenSSH only)

```powershell
# Generate SSH key pair
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_rsa" -C "backup@mycomputer"

# Copy public key to Linux server (easiest method)
type "$env:USERPROFILE\.ssh\id_rsa.pub" | ssh admin@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# Test connection
ssh -i "$env:USERPROFILE\.ssh\id_rsa" admin@192.168.1.100
```

### Step 2: Run Your First Backup

```powershell
Import-Module BackupToLinux

# Using OpenSSH with SSH key
Sync-ToLinux `
    -Source "C:\Documents" `
    -Destination "/backup/documents" `
    -HostName "192.168.1.100" `
    -UserName "admin" `
    -UseOpenSSH `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
```

## Usage Examples

### OpenSSH Examples (Recommended)

**Basic backup with SSH key:**
```powershell
Sync-ToLinux `
    -Source "C:\Data" `
    -Destination "/backup/data" `
    -HostName "myserver.com" `
    -UserName "admin" `
    -UseOpenSSH `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
```

**Using default SSH keys:**
```powershell
# Uses keys from ~/.ssh/ automatically (id_rsa, id_ed25519, etc.)
Sync-ToLinux `
    -Source "C:\Projects" `
    -Destination "/backup/projects" `
    -HostName "myserver.com" `
    -UserName "admin" `
    -UseOpenSSH
```

**Dry run (preview only):**
```powershell
Sync-ToLinux `
    -Source "C:\Important" `
    -Destination "/backup" `
    -HostName "192.168.1.100" `
    -UserName "admin" `
    -UseOpenSSH `
    -DryRun
```

### Posh-SSH Examples (Alternative)

**With password prompt:**
```powershell
Sync-ToLinux `
    -Source "C:\Documents" `
    -Destination "/backup/docs" `
    -HostName "192.168.1.100" `
    -UserName "admin"
# You'll be prompted for password
```

**With stored credentials:**
```powershell
$cred = Get-Credential
Sync-ToLinux `
    -Source "C:\Projects" `
    -Destination "/backup/projects" `
    -HostName "myserver.com" `
    -Credential $cred
```

**With SSH key:**
```powershell
Sync-ToLinux `
    -Source "C:\Data" `
    -Destination "/backup/data" `
    -HostName "myserver.com" `
    -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
```

### Advanced Features

**Exclude file patterns:**
```powershell
Sync-ToLinux `
    -Source "C:\Photos" `
    -Destination "/backup/photos" `
    -HostName "nas.local" `
    -UserName "admin" `
    -UseOpenSSH `
    -ExcludePatterns @("*.tmp", "*.cache", "Thumbs.db", ".DS_Store")
```

**Mirror mode (delete orphaned files):**
```powershell
Sync-ToLinux `
    -Source "C:\Sync" `
    -Destination "/home/user/sync" `
    -HostName "192.168.1.100" `
    -UserName "admin" `
    -UseOpenSSH `
    -DeleteOrphaned
```

**Verbose output:**
```powershell
Sync-ToLinux `
    -Source "C:\Data" `
    -Destination "/backup" `
    -HostName "192.168.1.100" `
    -UserName "admin" `
    -UseOpenSSH `
    -Verbose
```

## Parameters Reference

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Source` | String | Yes | Local Windows path to backup |
| `Destination` | String | Yes | Remote Linux destination path |
| `HostName` | String | Yes | Remote server hostname or IP address |
| `UserName` | String | Yes | SSH username |
| `UseOpenSSH` | Switch | No | Use native OpenSSH instead of Posh-SSH |
| `KeyFile` | String | No | Path to SSH private key file |
| `Credential` | PSCredential | No | Credential object (Posh-SSH only) |
| `Password` | String | No | Plain text password (Posh-SSH only, not recommended) |
| `Port` | Int | No | SSH port (default: 22) |
| `ExcludePatterns` | String[] | No | Array of wildcard patterns to exclude |
| `DryRun` | Switch | No | Preview mode - don't transfer files |
| `DeleteOrphaned` | Switch | No | Delete remote files not present locally |
| `Verbose` | Switch | No | Show detailed progress information |

## How It Works

1. **Connects** to remote Linux system via SSH
2. **Scans** local source directory recursively
3. **Builds** remote file index (path, size, modification time)
4. **Compares** each local file:
   - Different sizes → transfer
   - Different timestamps → transfer (2-second tolerance)
   - Matching size and time → skip
5. **Transfers** only changed files using SCP (OpenSSH) or SFTP (Posh-SSH)
6. **Preserves** original modification timestamps
7. **Reports** summary statistics

## Automation with Task Scheduler

### Create a Backup Script

Save as `C:\Scripts\DailyBackup.ps1`:

```powershell
# Configure logging
$logFile = "C:\Logs\backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $logFile

try {
    Import-Module BackupToLinux
    
    Sync-ToLinux `
        -Source "C:\Data" `
        -Destination "/backup/data" `
        -HostName "backup-server.local" `
        -UserName "backupuser" `
        -UseOpenSSH `
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

### Create Scheduled Task via GUI

1. Open Task Scheduler
2. Create Basic Task
3. Name: "Daily Linux Backup"
4. Trigger: Daily at 2:00 AM
5. Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\Scripts\DailyBackup.ps1"`
6. Finish

### Create Scheduled Task via PowerShell

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File C:\Scripts\DailyBackup.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 2am

Register-ScheduledTask -TaskName "Daily Linux Backup" `
    -Action $action `
    -Trigger $trigger `
    -Description "Automated backup to Linux server"
```

## SSH Key Setup Guide

### Generate SSH Keys

**Ed25519 (recommended, modern):**
```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519" -C "backup@mypc"
```

**RSA (compatible with older systems):**
```powershell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\id_rsa" -C "backup@mypc"
```

### Copy Public Key to Linux Server

**Method 1: Using ssh-copy-id (if available):**
```powershell
type "$env:USERPROFILE\.ssh\id_ed25519.pub" | ssh admin@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**Method 2: Manual:**
```powershell
# 1. Display your public key
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"

# 2. On Linux server, run:
# mkdir -p ~/.ssh
# nano ~/.ssh/authorized_keys
# (paste the public key, save)
# chmod 700 ~/.ssh
# chmod 600 ~/.ssh/authorized_keys
```

### Test SSH Connection

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" admin@192.168.1.100
```

## Troubleshooting

### "OpenSSH client not found"
**Solution:** Install OpenSSH Client via Settings > Apps > Optional Features

### "Posh-SSH module not found"
**Solution:** 
```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser
```

### "SSH connection failed"
**Check:**
- Hostname/IP is correct and reachable: `ping 192.168.1.100`
- SSH service running on remote: Port 22 open
- Firewall allows SSH connections
- SSH key permissions (should be 600/400)

### "Permission denied (publickey)"
**Solutions:**
1. Verify public key is in `~/.ssh/authorized_keys` on Linux server
2. Check permissions:
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```
3. Check SSH key path is correct in command

### Files always transfer even when unchanged
**Causes:**
- Clock sync issue between systems (use NTP)
- Filesystem doesn't preserve timestamps
- Network filesystem limitations

### OpenSSH password authentication not working
**Note:** OpenSSH cannot use passwords from PowerShell. Use SSH keys or switch to Posh-SSH.

## Security Best Practices

1. **Use SSH keys** instead of passwords
2. **Protect private keys** with strong passphrases
3. **Use dedicated backup user** with minimal permissions
4. **Limit SSH key scope** with authorized_keys options:
   ```
   from="192.168.1.0/24",command="/usr/bin/rsync" ssh-ed25519 AAAA...
   ```
5. **Enable SSH key-only auth** on server (disable password auth)
6. **Keep audit logs** of backup operations
7. **Use firewall rules** to limit SSH access
8. **Regular key rotation** (annually recommended)

## Performance Tips

- Run during off-peak hours for large backups
- Use `-Verbose` sparingly (adds overhead)
- Exclude temporary/cache files with `-ExcludePatterns`
- Test with `-DryRun` first to estimate transfer time
- Ensure adequate network bandwidth
- For massive backups, consider rsync alternatives

## Comparison: OpenSSH vs Posh-SSH vs WinSCP

| Feature | OpenSSH | Posh-SSH | WinSCP |
|---------|---------|----------|--------|
| Installation | Built-in Win10+ | PowerShell module | Separate app |
| Password auth | ❌ | ✅ | ✅ |
| SSH key auth | ✅ | ✅ | ✅ |
| Performance | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| Automation | ✅ Easy | ✅ Easy | ⚠️ Custom script |
| GUI | ❌ | ❌ | ✅ |
| Native integration | ✅ | ❌ | ❌ |

## Examples for Common Scenarios

### Scenario 1: Home User - Daily Photo Backup
```powershell
Sync-ToLinux `
    -Source "C:\Users\John\Pictures" `
    -Destination "/mnt/nas/photos" `
    -HostName "nas.home" `
    -UserName "john" `
    -UseOpenSSH `
    -ExcludePatterns @("*.tmp", "Thumbs.db")
```

### Scenario 2: Developer - Code Backup to VPS
```powershell
Sync-ToLinux `
    -Source "C:\Projects" `
    -Destination "/backup/code" `
    -HostName "vps.example.com" `
    -UserName "developer" `
    -UseOpenSSH `
    -KeyFile "$env:USERPROFILE\.ssh\vps_key" `
    -Port 2222 `
    -ExcludePatterns @("node_modules", "*.log", "bin", "obj")
```

### Scenario 3: Business - Database Backup
```powershell
Sync-ToLinux `
    -Source "C:\DatabaseBackups" `
    -Destination "/secure/backups/databases" `
    -HostName "backup.company.com" `
    -UserName "svc_backup" `
    -UseOpenSSH `
    -KeyFile "$env:USERPROFILE\.ssh\backup_key" `
    -Verbose
```

## License

This module is provided as-is for personal and commercial use. Feel free to modify and redistribute.

## Contributing

Contributions welcome! Common enhancement ideas:
- Email notifications on completion/failure
- Compression before transfer
- Bandwidth throttling
- Retry logic for failed transfers
- Multiple source directories
- Checksum verification option

## Support

- For Posh-SSH issues: https://github.com/darkoperator/Posh-SSH
- For OpenSSH issues: Check Windows OpenSSH documentation
- For module bugs: Review this README or modify the .psm1 file

## Version History

- **v2.0** - Added native OpenSSH support
- **v1.0** - Initial release with Posh-SSH support
