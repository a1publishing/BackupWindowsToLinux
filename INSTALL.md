# BackupToLinux Module Installation Guide

## Quick Installation

### Step 1: Create Module Folder Structure

```powershell
# Decide on user or system installation
# User modules (recommended for personal use):
#$modulePath = "$HOME\Documents\WindowsPowerShell\Modules\BackupToLinux"
$modulePath = "$HOME\Documents\PowerShell\Modules\BackupToLinux"


# OR System modules (requires admin, available to all users):
# $modulePath = "C:\Program Files\WindowsPowerShell\Modules\BackupToLinux"

# Create the folder
New-Item -Path $modulePath -ItemType Directory -Force
```

### Step 2: Copy Module Files

Copy these files into the `BackupToLinux` folder:
- `BackupToLinux.psm1` (the module script - **required**)
- `BackupToLinux.psd1` (the manifest - **required**)
- `README.md` (documentation - **optional but recommended**)

```powershell
# Example copy commands (adjust source paths as needed)
Copy-Item "BackupToLinux.psm1" -Destination $modulePath
Copy-Item "BackupToLinux.psd1" -Destination $modulePath
Copy-Item "README.md" -Destination $modulePath  # Optional
```

### Step 3: Verify Installation

```powershell
# List available modules (should see BackupToLinux)
Get-Module -ListAvailable -Name BackupToLinux

# Import the module
Import-Module BackupToLinux

# Verify the function is available
Get-Command Sync-ToLinux

# View module info
Get-Module BackupToLinux | Format-List
```

## Final Folder Structure

Your module folder should look like this:

```
C:\Users\YourName\Documents\WindowsPowerShell\Modules\
└── BackupToLinux\
    ├── BackupToLinux.psm1    (required - the module code)
    ├── BackupToLinux.psd1    (required - the manifest)
    └── README.md             (optional - documentation)
```

## Using the Module

### Auto-Import (Recommended)

Once installed in your modules path, PowerShell will auto-import it when you use `Sync-ToLinux`:

```powershell
# Just use it - auto-imports automatically
Sync-ToLinux -Source "C:\Data" -Destination "/backup/data" `
    -HostName "192.168.1.100" -UserName "admin" `
    -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
```

### Manual Import

Or explicitly import it:

```powershell
Import-Module BackupToLinux

# Now use it
Sync-ToLinux -Source "C:\Data" -Destination "/backup"
```

### Add to Profile (Always Available)

To have it available in every PowerShell session:

```powershell
# Edit your PowerShell profile
notepad $PROFILE

# Add this line to the file:
Import-Module BackupToLinux

# Save and close
```

## Getting Help

```powershell
# View detailed help
Get-Help Sync-ToLinux -Detailed

# View examples
Get-Help Sync-ToLinux -Examples

# View all parameters
Get-Help Sync-ToLinux -Parameter *
```

## Updating the Module

To update to a newer version:

1. Delete the old files from the module folder
2. Copy the new files in
3. Restart PowerShell (or run `Remove-Module BackupToLinux; Import-Module BackupToLinux`)

## Uninstalling

```powershell
# Remove from current session
Remove-Module BackupToLinux

# Delete the module folder
$modulePath = "$HOME\Documents\WindowsPowerShell\Modules\BackupToLinux"
Remove-Item -Path $modulePath -Recurse -Force
```

## Troubleshooting

### "Module not found"
- Check the folder name matches the module name exactly: `BackupToLinux`
- Verify files are in the correct location
- Try: `Get-Module -ListAvailable` to see all modules

### "Cannot be loaded because running scripts is disabled"
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set to RemoteSigned (recommended) or Unrestricted
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Function not found after import"
- Verify the .psm1 file has `Export-ModuleMember -Function Sync-ToLinux` at the end
- Check manifest has `FunctionsToExport = @('Sync-ToLinux')`

## Module Locations

PowerShell searches these locations for modules (in order):

```powershell
# View your module paths
$env:PSModulePath -split ';'
```

Common paths:
1. **User modules:** `C:\Users\YourName\Documents\WindowsPowerShell\Modules`
2. **System modules:** `C:\Program Files\WindowsPowerShell\Modules`
3. **Built-in modules:** `C:\Windows\System32\WindowsPowerShell\v1.0\Modules`

Choose user modules for personal use, system modules for all users.

## Summary Checklist

- [ ] Create folder: `~\Documents\WindowsPowerShell\Modules\BackupToLinux\`
- [ ] Copy `BackupToLinux.psm1` to folder
- [ ] Copy `BackupToLinux.psd1` to folder
- [ ] Copy `README.md` to folder (optional)
- [ ] Verify: `Get-Module -ListAvailable -Name BackupToLinux`
- [ ] Test: `Import-Module BackupToLinux`
- [ ] Confirm: `Get-Command Sync-ToLinux`
- [ ] Use it! `Sync-ToLinux -Source ... -Destination ...`

Done! The module is now properly installed and ready to use.
