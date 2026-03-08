@{
    RootModule        = 'BackupWindowsToLinux.psm1'
    ModuleVersion     = '2.0.0'
    GUID              = 'a8f4c3d2-1e5b-4a9c-8f7d-2b6e9c4a1f8e'
    Author            = 'Mike Flynn'
    CompanyName       = 'a1publishing.com'
    Copyright         = '(c) 2026 Mike Flynn. All rights reserved.'
    Description       = 'PowerShell module for incremental backups from Windows to Linux via OpenSSH. Only transfers new or modified files. Supports long filenames, special characters (£, €, apostrophes), and UTF-8 encoding. Uses native Windows OpenSSH (no dependencies).'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Sync-ToLinux')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags        = @('Backup', 'SSH', 'OpenSSH', 'Linux', 'Windows', 'Sync', 'Incremental', 'SCP')
            LicenseUri  = 'https://github.com/a1publishing/BackupWindowsToLinux/blob/main/LICENSE'
            ProjectUri  = 'https://github.com/a1publishing/BackupWindowsToLinux'
            ReleaseNotes = @'
## 2.0.0
- Native OpenSSH support (Windows 10+)
- Removed Posh-SSH dependency
- Full UTF-8 support for special characters (£, €, etc.)
- Support for long filenames (600+ characters)
- Support for UNC paths
- Automatic fallback for complex paths
- Improved error handling and reporting
- Directory exclusion patterns
- Orphaned file and directory cleanup
'@
        }
    }
}
