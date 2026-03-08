function Sync-ToLinux {
    <#
    .SYNOPSIS
        Synchronizes files from Windows to a remote Linux system using OpenSSH
    .PARAMETER Source
        Local Windows path to backup (e.g., "C:\Data")
    .PARAMETER Destination
        Remote Linux path (e.g., "/home/user/backups")
    .PARAMETER HostName
        Remote Linux hostname or IP address
    .PARAMETER UserName
        SSH username for remote system
    .PARAMETER KeyFile
        Path to SSH private key file for key-based authentication (required for automated backups)
    .PARAMETER Port
        SSH port (default: 22)
    .PARAMETER ExcludePatterns
        Array of wildcard patterns to exclude files and directories
    .PARAMETER DryRun
        Show what would be transferred without actually transferring
    .PARAMETER DeleteOrphaned
        Delete files and directories on remote that no longer exist locally
    .PARAMETER Verbose
        Show detailed progress information
    .EXAMPLE
        Sync-ToLinux -Source "C:\Documents" -Destination "/backup/docs" -HostName "192.168.1.100" -UserName "admin" -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
    .EXAMPLE
        Sync-ToLinux -Source "C:\Projects" -Destination "/backup" -HostName "server.com" -UserName "admin" -KeyFile "$env:USERPROFILE\.ssh\id_rsa" -Verbose
    .EXAMPLE
        Sync-ToLinux -Source "C:\Code" -Destination "/backup/code" -HostName "server.com" -UserName "admin" -KeyFile "$env:USERPROFILE\.ssh\backup_key" -ExcludePatterns @("node_modules", ".git", "*.tmp")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$true)]
        [string]$HostName,

        [Parameter(Mandatory=$true)]
        [string]$UserName,

        [string]$KeyFile,

        [int]$Port = 22,

        [string[]]$ExcludePatterns = @(),

        [switch]$DryRun,

        [switch]$DeleteOrphaned
    )

    $session = [LinuxBackupSession]::new(
        $Source,
        $Destination,
        $HostName,
        $UserName,
        $KeyFile,
        $Port,
        $ExcludePatterns,
        $DryRun.IsPresent,
        $DeleteOrphaned.IsPresent,
        $VerbosePreference
    )

    $session.Execute()
}
