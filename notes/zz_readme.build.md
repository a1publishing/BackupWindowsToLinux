# Developer Build & Publish Guide

## Prerequisites

Install required modules once (run as your normal user):

```powershell
Install-Module InvokeBuild   -MinimumVersion 5.6.7  -Scope CurrentUser
Install-Module ModuleBuilder  -Scope CurrentUser
Install-Module Pester        -MinimumVersion 5.1.1  -Scope CurrentUser -Force
# Optional — enables automatic semantic versioning from git history
Install-Module GitVersion.CommandLine -Scope CurrentUser
```

## Directory Layout

```
Source/                     # All module source code
  Classes/                  # PowerShell classes (dot-sourced first)
  Public/                   # Exported functions
  Private/                  # Internal helpers (not exported)
  _PrefixCode.ps1           # Prepended to compiled .psm1
  BackupWindowsToLinux.psm1 # Dev loader (dot-sources everything)
  BackupWindowsToLinux.psd1 # Module manifest
  build.psd1                # ModuleBuilder configuration

Test/
  Unit/
    BackupWindowsToLinux.Tests.ps1

bin/                        # Build output (git-ignored)
  BackupWindowsToLinux/
    2.0.0/                  # Versioned compiled module

BackupWindowsToLinux.build.ps1  # InvokeBuild tasks
```

## Build Tasks

All tasks are run via `Invoke-Build` from the repo root.

| Command | What it does |
|---------|--------------|
| `Invoke-Build` | Default: Clean → TestCode → CompilePSM → TestBuild |
| `Invoke-Build Clean` | Delete `.\bin` |
| `Invoke-Build TestCode` | Run Pester against source (pre-build) |
| `Invoke-Build CompilePSM` | Build compiled module into `bin/` |
| `Invoke-Build TestBuild` | Run Pester against compiled module |
| `Invoke-Build Build` | CompilePSM + TestBuild |
| `Invoke-Build Publish` | Publish to PSGallery (see below) |

## Running Tests Only

```powershell
# Against source (fast, no build needed)
$f = "$PSScriptRoot\Test\tmp\data.ps1"
New-Item -ItemType Directory "$PSScriptRoot\Test\tmp" -Force | Out-Null
"ModulePath=$PSScriptRoot\Source\" | Out-File $f
Invoke-Pester -Path .\Test\Unit -Container (New-PesterContainer -Path 'BackupWindowsToLinux.Tests.ps1' -Data @{ File = $f })
```

## Install to Custom Module Path

After building, copy to your PowerShell module search path:

```powershell
$version = '2.0.0'
$dest = "S:\lib\pow\mod\BackupWindowsToLinux"
Copy-Item -Path ".\bin\BackupWindowsToLinux\$version" -Destination $dest -Recurse -Force
```

Verify:
```powershell
Import-Module BackupWindowsToLinux
Get-Command Sync-ToLinux
```

## Publish to PowerShell Gallery

1. Obtain your NuGet API key from https://www.powershellgallery.com/account/apikeys
2. Either set the environment variable or let the build task prompt you:

```powershell
$env:PSGALLERY_KEY = 'your-api-key-here'
Invoke-Build Publish
```

Allow ~15 minutes for the listing to appear on PSGallery.

## Versioning

Version is controlled by `Source/BackupWindowsToLinux.psd1` (`ModuleVersion`).
If `gitversion` is installed, `Invoke-Build CompilePSM` will override the version
from git history automatically (based on `GitVersion.yml`).

To bump version manually: edit `ModuleVersion` in `Source/BackupWindowsToLinux.psd1`
and update `next-version` in `GitVersion.yml` to match.
