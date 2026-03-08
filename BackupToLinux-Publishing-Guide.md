# BackupToLinux PowerShell Module - Publishing Guide

## Overview

This guide outlines the steps needed to publish the BackupToLinux module to the PowerShell Gallery via GitHub. It covers testing, build automation, versioning, and CI/CD pipeline setup.

---

## Assessment of Current Plan

Your approach is excellent and follows PowerShell community best practices:

- ✅ **Pester for testing** - Still the de facto standard for PowerShell testing
- ✅ **GitHub + PowerShell Gallery** - Perfect workflow for open source modules
- ✅ **Build automation** - Essential for quality and streamlined releases
- ✅ **Semantic versioning** - Critical for dependency management
- ✅ **Claude Code Pro** - Will accelerate development, especially for testing and CI/CD

---

## Project Roadmap

### Phase 1: Repository Setup (30 minutes)

#### 1.1 Initialize Git Repository

```bash
cd BackupToLinux
git init
```

#### 1.2 Create `.gitignore`

```gitignore
# PowerShell artifacts
*.ps1xml
PSScriptAnalyzerSettings.psd1

# Test results
TestResults/
*.trx

# Build outputs
Build/
Release/
Publish/

# Sensitive data
*.key
*.pem
id_rsa*
*.pfx

# IDE
.vscode/
.vs/
*.code-workspace

# OS
.DS_Store
Thumbs.db
```

#### 1.3 Create README.md

```markdown
# BackupToLinux

PowerShell module for backing up Windows files to remote Linux systems via SSH/SCP.

## Features

- Incremental backup based on file size and modification time
- SSH key authentication support
- File and directory exclusion patterns
- Dry-run mode for testing
- Orphaned file cleanup
- UTF-8 support for international characters

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name BackupToLinux
```

### Manual Installation

```powershell
# Clone the repository
git clone https://github.com/a1publishing/BackupToLinux.git

# Import the module
Import-Module .\BackupToLinux\BackupToLinux.psm1
```

## Usage

### Basic Backup

```powershell
Sync-ToLinux -Source "C:\Documents" `
             -Destination "/backup/docs" `
             -HostName "192.168.1.100" `
             -UserName "admin" `
             -KeyFile "$env:USERPROFILE\.ssh\id_rsa"
```

### With Exclusions

```powershell
Sync-ToLinux -Source "C:\Projects" `
             -Destination "/backup/projects" `
             -HostName "server.local" `
             -UserName "backup" `
             -KeyFile "$env:USERPROFILE\.ssh\backup_key" `
             -ExcludePatterns @("node_modules", ".git", "*.tmp", "bin", "obj")
```

### Dry Run

```powershell
Sync-ToLinux -Source "C:\Data" `
             -Destination "/backup/data" `
             -HostName "nas.local" `
             -UserName "admin" `
             -KeyFile "$env:USERPROFILE\.ssh\id_rsa" `
             -DryRun
```

### Delete Orphaned Files

```powershell
Sync-ToLinux -Source "C:\Archive" `
             -Destination "/backup/archive" `
             -HostName "backup.local" `
             -UserName "admin" `
             -KeyFile "$env:USERPROFILE\.ssh\id_rsa" `
             -DeleteOrphaned
```

## Requirements

- Windows 10/11 or Windows Server 2019+
- OpenSSH Client (built into modern Windows)
- SSH access to target Linux system
- PowerShell 5.1 or PowerShell 7+

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please see CONTRIBUTING.md for guidelines.
```

#### 1.4 Create LICENSE (MIT)

```text
MIT License

Copyright (c) 2025 A1 Publishing

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### 1.5 Create Module Manifest (BackupToLinux.psd1)

```powershell
New-ModuleManifest -Path .\BackupToLinux.psd1 `
    -Author "A1 Publishing" `
    -CompanyName "A1 Publishing" `
    -Copyright "(c) 2025 A1 Publishing. All rights reserved." `
    -Description "PowerShell module for backing up Windows files to remote Linux systems via SSH/SCP. Supports incremental backups, SSH key authentication, file exclusions, and orphaned file cleanup." `
    -ModuleVersion "1.0.0" `
    -PowerShellVersion "5.1" `
    -RootModule "BackupToLinux.psm1" `
    -FunctionsToExport @('Sync-ToLinux') `
    -CmdletsToExport @() `
    -VariablesToExport @() `
    -AliasesToExport @() `
    -Tags @('Backup', 'SSH', 'Linux', 'SCP', 'Sync', 'Transfer') `
    -ProjectUri "https://github.com/a1publishing/BackupToLinux" `
    -LicenseUri "https://github.com/a1publishing/BackupToLinux/blob/main/LICENSE" `
    -ReleaseNotes "Initial release - v1.0.0"
```

---

### Phase 2: Testing Infrastructure (2-3 hours)

#### 2.1 Install Development Dependencies

```powershell
# Install Pester (testing framework)
Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0

# Install PSScriptAnalyzer (code quality)
Install-Module -Name PSScriptAnalyzer -Force

# Install build tool (choose one)
Install-Module -Name psake -Force  # Recommended
# OR
Install-Module -Name Invoke-Build -Force
```

#### 2.2 Create Test Directory Structure

```
BackupToLinux/
├── BackupToLinux.psm1
├── BackupToLinux.psd1
├── Tests/
│   ├── Unit/
│   │   ├── LinuxBackupSession.Constructor.Tests.ps1
│   │   ├── LinuxBackupSession.Validation.Tests.ps1
│   │   ├── LinuxBackupSession.FileOperations.Tests.ps1
│   │   └── Sync-ToLinux.Tests.ps1
│   └── Integration/
│       └── E2E.Tests.ps1
└── Build/
    └── build.ps1
```

#### 2.3 Sample Unit Test (Tests/Unit/LinuxBackupSession.Constructor.Tests.ps1)

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot\..\..\BackupToLinux.psd1" -Force
}

Describe 'LinuxBackupSession Constructor' {
    It 'Creates session with valid parameters' {
        $session = [LinuxBackupSession]::new(
            'C:\Source',
            '/backup',
            'server.local',
            'admin',
            'C:\key.pem',
            22,
            @(),
            $false,
            $false,
            'SilentlyContinue'
        )
        
        $session.Source | Should -Be 'C:\Source'
        $session.Destination | Should -Be '/backup'
        $session.HostName | Should -Be 'server.local'
        $session.Port | Should -Be 22
    }
    
    It 'Initializes empty collections' {
        $session = [LinuxBackupSession]::new(
            'C:\Source', '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue'
        )
        
        $session.remoteIndex.Count | Should -Be 0
        $session.createdDirs.Count | Should -Be 0
        $session.stats.Total | Should -Be 0
    }
}

Describe 'LinuxBackupSession.TestOpenSSHClient' {
    BeforeAll {
        Mock Get-Command { 
            return @{ Name = 'ssh' }
        } -ParameterFilter { $Name -eq 'ssh' }
        
        Mock Get-Command { 
            return @{ Name = 'scp' }
        } -ParameterFilter { $Name -eq 'scp' }
    }
    
    It 'Returns true when SSH and SCP are available' {
        $session = [LinuxBackupSession]::new(
            'C:\Source', '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue'
        )
        
        $result = $session.TestOpenSSHClient()
        $result | Should -Be $true
    }
}

Describe 'LinuxBackupSession.ConvertToBashEscapedString' {
    It 'Escapes single quotes correctly' {
        $session = [LinuxBackupSession]::new(
            'C:\Source', '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue'
        )
        
        $result = $session.ConvertToBashEscapedString("test's file")
        $result | Should -Be "test'\''s file"
    }
    
    It 'Handles strings without special characters' {
        $session = [LinuxBackupSession]::new(
            'C:\Source', '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue'
        )
        
        $result = $session.ConvertToBashEscapedString("normal_path")
        $result | Should -Be "normal_path"
    }
}
```

#### 2.4 Sample Integration Test (Tests/Integration/E2E.Tests.ps1)

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot\..\..\BackupToLinux.psd1" -Force
}

Describe 'Sync-ToLinux End-to-End' -Tag 'Integration' {
    BeforeAll {
        # Set up test environment variables
        $script:TestSource = $env:BACKUP_TEST_SOURCE
        $script:TestDest = $env:BACKUP_TEST_DEST
        $script:TestHost = $env:BACKUP_TEST_HOST
        $script:TestUser = $env:BACKUP_TEST_USER
        $script:TestKey = $env:BACKUP_TEST_KEY
        
        # Skip if not configured
        if (-not ($TestSource -and $TestDest -and $TestHost -and $TestUser -and $TestKey)) {
            Set-ItResult -Skipped -Because "Integration test environment not configured"
        }
    }
    
    It 'Performs full backup successfully' -Skip:(-not $TestSource) {
        { 
            Sync-ToLinux -Source $TestSource `
                         -Destination $TestDest `
                         -HostName $TestHost `
                         -UserName $TestUser `
                         -KeyFile $TestKey
        } | Should -Not -Throw
    }
    
    It 'Dry-run completes without errors' -Skip:(-not $TestSource) {
        { 
            Sync-ToLinux -Source $TestSource `
                         -Destination $TestDest `
                         -HostName $TestHost `
                         -UserName $TestUser `
                         -KeyFile $TestKey `
                         -DryRun
        } | Should -Not -Throw
    }
}
```

#### 2.5 Run Tests

```powershell
# Run all tests
Invoke-Pester

# Run with coverage
Invoke-Pester -CodeCoverage .\BackupToLinux.psm1

# Run specific tests
Invoke-Pester -Path .\Tests\Unit\

# Run and generate report
Invoke-Pester -OutputFormat NUnitXml -OutputFile TestResults.xml
```

---

### Phase 3: Build Automation (1-2 hours)

#### 3.1 Create Build Script (Build/build.ps1 using psake)

```powershell
# Build/build.ps1
properties {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $moduleRoot = $projectRoot
    $moduleName = 'BackupToLinux'
    $outputDir = Join-Path $projectRoot 'Output'
    $testResultsDir = Join-Path $projectRoot 'TestResults'
}

Task default -Depends Test, Build

Task Init {
    Write-Host "Initializing build environment..." -ForegroundColor Cyan
    
    # Create output directories
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    if (-not (Test-Path $testResultsDir)) {
        New-Item -ItemType Directory -Path $testResultsDir | Out-Null
    }
}

Task Clean -Depends Init {
    Write-Host "Cleaning output directories..." -ForegroundColor Cyan
    
    if (Test-Path $outputDir) {
        Remove-Item $outputDir\* -Recurse -Force
    }
    if (Test-Path $testResultsDir) {
        Remove-Item $testResultsDir\* -Recurse -Force
    }
}

Task Analyze {
    Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Cyan
    
    $moduleFile = Join-Path $moduleRoot "$moduleName.psm1"
    $results = Invoke-ScriptAnalyzer -Path $moduleFile -Severity Warning,Error
    
    if ($results) {
        Write-Host "Script analysis failed!" -ForegroundColor Red
        $results | Format-Table
        throw "PSScriptAnalyzer found issues"
    }
    
    Write-Host "Script analysis passed!" -ForegroundColor Green
}

Task Test -Depends Analyze {
    Write-Host "Running Pester tests..." -ForegroundColor Cyan
    
    $testConfig = New-PesterConfiguration
    $testConfig.Run.Path = Join-Path $projectRoot 'Tests'
    $testConfig.Run.PassThru = $true
    $testConfig.CodeCoverage.Enabled = $true
    $testConfig.CodeCoverage.Path = Join-Path $moduleRoot "$moduleName.psm1"
    $testConfig.TestResult.Enabled = $true
    $testConfig.TestResult.OutputPath = Join-Path $testResultsDir 'TestResults.xml'
    $testConfig.Output.Verbosity = 'Detailed'
    
    $results = Invoke-Pester -Configuration $testConfig
    
    if ($results.FailedCount -gt 0) {
        throw "$($results.FailedCount) test(s) failed"
    }
    
    Write-Host "All tests passed!" -ForegroundColor Green
    Write-Host "Code Coverage: $([math]::Round($results.CodeCoverage.CoveragePercent, 2))%" -ForegroundColor Cyan
}

Task Build -Depends Test {
    Write-Host "Building module..." -ForegroundColor Cyan
    
    $moduleOutputDir = Join-Path $outputDir $moduleName
    if (-not (Test-Path $moduleOutputDir)) {
        New-Item -ItemType Directory -Path $moduleOutputDir | Out-Null
    }
    
    # Copy module files
    Copy-Item -Path (Join-Path $moduleRoot "$moduleName.psm1") -Destination $moduleOutputDir
    Copy-Item -Path (Join-Path $moduleRoot "$moduleName.psd1") -Destination $moduleOutputDir
    
    # Copy README and LICENSE
    if (Test-Path (Join-Path $projectRoot 'README.md')) {
        Copy-Item -Path (Join-Path $projectRoot 'README.md') -Destination $moduleOutputDir
    }
    if (Test-Path (Join-Path $projectRoot 'LICENSE')) {
        Copy-Item -Path (Join-Path $projectRoot 'LICENSE') -Destination $moduleOutputDir
    }
    
    Write-Host "Module built successfully in: $moduleOutputDir" -ForegroundColor Green
}

Task UpdateVersion {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Major', 'Minor', 'Patch')]
        [string]$VersionBump
    )
    
    Write-Host "Updating module version ($VersionBump)..." -ForegroundColor Cyan
    
    $manifestPath = Join-Path $moduleRoot "$moduleName.psd1"
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $currentVersion = [version]$manifest.ModuleVersion
    
    switch ($VersionBump) {
        'Major' { $newVersion = [version]::new($currentVersion.Major + 1, 0, 0) }
        'Minor' { $newVersion = [version]::new($currentVersion.Major, $currentVersion.Minor + 1, 0) }
        'Patch' { $newVersion = [version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1) }
    }
    
    Update-ModuleManifest -Path $manifestPath -ModuleVersion $newVersion
    
    Write-Host "Version updated: $currentVersion -> $newVersion" -ForegroundColor Green
}

Task Publish -Depends Build {
    param(
        [Parameter(Mandatory)]
        [string]$NuGetApiKey
    )
    
    Write-Host "Publishing to PowerShell Gallery..." -ForegroundColor Cyan
    
    $moduleOutputDir = Join-Path $outputDir $moduleName
    
    try {
        Publish-Module -Path $moduleOutputDir -NuGetApiKey $NuGetApiKey -Verbose
        Write-Host "Module published successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Publication failed: $_" -ForegroundColor Red
        throw
    }
}
```

#### 3.2 Run Build

```powershell
# Run default tasks (Test, Build)
Invoke-psake .\Build\build.ps1

# Run specific task
Invoke-psake .\Build\build.ps1 -taskList Clean

# Update version
Invoke-psake .\Build\build.ps1 -taskList UpdateVersion -parameters @{ VersionBump = 'Minor' }

# Publish (requires API key)
Invoke-psake .\Build\build.ps1 -taskList Publish -parameters @{ NuGetApiKey = $env:PSGALLERY_API_KEY }
```

---

### Phase 4: CI/CD Pipeline (1-2 hours)

#### 4.1 Create GitHub Actions Workflow (.github/workflows/ci.yml)

```yaml
name: CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  release:
    types: [ published ]

env:
  MODULE_NAME: BackupToLinux

jobs:
  test:
    name: Test on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [windows-latest, ubuntu-latest]
        
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Install Pester
      shell: pwsh
      run: |
        Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0
        Install-Module -Name PSScriptAnalyzer -Force
        
    - name: Run PSScriptAnalyzer
      shell: pwsh
      run: |
        $results = Invoke-ScriptAnalyzer -Path ./${{ env.MODULE_NAME }}.psm1 -Severity Warning,Error
        if ($results) {
          $results | Format-Table
          throw "PSScriptAnalyzer found issues"
        }
        
    - name: Run Pester Tests
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests'
        $config.Run.PassThru = $true
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = './${{ env.MODULE_NAME }}.psm1'
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = './TestResults.xml'
        $config.TestResult.OutputFormat = 'NUnitXml'
        
        $results = Invoke-Pester -Configuration $config
        
        if ($results.FailedCount -gt 0) {
          throw "$($results.FailedCount) test(s) failed"
        }
        
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results-${{ matrix.os }}
        path: TestResults.xml
        
    - name: Publish test results
      uses: EnricoMi/publish-unit-test-result-action/composite@v2
      if: always() && matrix.os == 'ubuntu-latest'
      with:
        files: TestResults.xml

  publish:
    name: Publish to PowerShell Gallery
    needs: test
    runs-on: windows-latest
    if: github.event_name == 'release'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      
    - name: Publish Module
      shell: pwsh
      env:
        PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
      run: |
        Publish-Module -Path . -NuGetApiKey $env:PSGALLERY_API_KEY -Verbose
```

#### 4.2 Set Up GitHub Secrets

1. Get PowerShell Gallery API Key:
   - Go to https://www.powershellgallery.com/
   - Sign in with your Microsoft account
   - Go to Account Settings → API Keys
   - Create a new API key

2. Add to GitHub:
   - Go to your repository on GitHub
   - Settings → Secrets and variables → Actions
   - New repository secret: `PSGALLERY_API_KEY`

---

### Phase 5: Documentation (1 hour)

#### 5.1 Create CHANGELOG.md

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-02-15

### Added
- Initial release
- Incremental backup based on file size and modification time
- SSH key authentication support
- File and directory exclusion patterns
- Dry-run mode for testing
- Orphaned file and directory cleanup
- UTF-8 support for international characters
- Object-oriented class design
- Comprehensive error handling

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A
```

#### 5.2 Create CONTRIBUTING.md

```markdown
# Contributing to BackupToLinux

Thank you for considering contributing to BackupToLinux! 

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates.

When reporting a bug, include:
- PowerShell version (`$PSVersionTable`)
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Any error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:
- Clear use case
- Expected behavior
- Any alternative solutions you've considered

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`Invoke-Pester`)
5. Run PSScriptAnalyzer (`Invoke-ScriptAnalyzer`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to your branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Coding Standards

- Follow PowerShell best practices
- Use approved PowerShell verbs
- Include comment-based help for public functions
- Write Pester tests for new functionality
- Maintain code coverage above 80%

### Testing

Run tests before submitting PR:

```powershell
# Run all tests
Invoke-Pester

# Run with coverage
Invoke-Pester -CodeCoverage .\BackupToLinux.psm1

# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path .\BackupToLinux.psm1
```

## Code of Conduct

Be respectful and constructive in all interactions.
```

#### 5.3 Add Badges to README.md

Add to the top of README.md:

```markdown
[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/BackupToLinux)](https://www.powershellgallery.com/packages/BackupToLinux)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/BackupToLinux)](https://www.powershellgallery.com/packages/BackupToLinux)
[![Build Status](https://github.com/a1publishing/BackupToLinux/workflows/CI%2FCD/badge.svg)](https://github.com/a1publishing/BackupToLinux/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
```

---

## Quick-Start Priority Order

### Must-Have First (Critical Path)

1. **Module Manifest** (.psd1) - Required for PSGallery
2. **Basic Pester Tests** - Prevent regressions
3. **Build Script** - Automate testing/packaging
4. **GitHub Actions** - Automate everything on push

### Nice-to-Have Later (Enhancement Path)

5. Comprehensive test coverage (aim for 80%+)
6. Code coverage reporting in CI
7. Integration tests with real SSH server
8. Performance benchmarks
9. Additional documentation (wiki, examples)

---

## Practical Implementation Steps

### Step 1: Local Setup

```powershell
# 1. Create module manifest
New-ModuleManifest -Path .\BackupToLinux.psd1 `
    -Author "Your Name" `
    -Description "Backup Windows files to Linux via SSH/SCP" `
    -ModuleVersion "1.0.0" `
    -RootModule "BackupToLinux.psm1" `
    -FunctionsToExport @('Sync-ToLinux')

# 2. Install dev dependencies
Install-Module -Name Pester -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Force
Install-Module -Name psake -Force

# 3. Create directory structure
New-Item -ItemType Directory -Path Tests\Unit
New-Item -ItemType Directory -Path Tests\Integration
New-Item -ItemType Directory -Path Build

# 4. Test module loads
Import-Module .\BackupToLinux.psd1 -Force
Get-Command -Module BackupToLinux
```

### Step 2: First Test

Create `Tests\Unit\Basic.Tests.ps1`:

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot\..\..\BackupToLinux.psd1" -Force
}

Describe 'Module Import' {
    It 'Imports successfully' {
        Get-Module BackupToLinux | Should -Not -BeNullOrEmpty
    }
    
    It 'Exports Sync-ToLinux function' {
        Get-Command Sync-ToLinux -Module BackupToLinux | Should -Not -BeNullOrEmpty
    }
}

Describe 'LinuxBackupSession Class' {
    It 'Can be instantiated' {
        { 
            [LinuxBackupSession]::new(
                'C:\test', '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue'
            )
        } | Should -Not -Throw
    }
}
```

Run it:

```powershell
Invoke-Pester .\Tests\Unit\Basic.Tests.ps1
```

### Step 3: Git Setup

```powershell
git init
git add .
git commit -m "Initial commit with working module"
git remote add origin https://github.com/a1publishing/BackupToLinux.git
git push -u origin main
```

### Step 4: First Release

```powershell
# 1. Test everything
Invoke-psake .\Build\build.ps1

# 2. Create git tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 3. Create GitHub Release
# Go to GitHub → Releases → Draft a new release
# Select tag v1.0.0, add release notes, publish

# 4. GitHub Actions will automatically publish to PSGallery
```

---

## Key Considerations

### Mocking SSH/SCP in Tests

Since the module calls external SSH/SCP commands, you need to mock them:

```powershell
BeforeAll {
    Mock -CommandName 'ssh' -MockWith {
        return "mocked output"
    }
    
    Mock -CommandName 'scp' -MockWith {
        $global:LASTEXITCODE = 0
        return $null
    }
}
```

### Versioning Scheme

Use Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Breaking Changes

The class-based architecture isolates internal changes. Only the `Sync-ToLinux` function signature matters for backward compatibility.

---

## Troubleshooting

### Common Issues

**Pester tests fail on Linux**
- Windows-specific path handling may need adjustment
- Use `Join-Path` instead of string concatenation

**PSScriptAnalyzer warnings**
- Review and address each warning
- Some can be suppressed with `[Diagnostics.CodeAnalysis.SuppressMessageAttribute()]`

**Module not found in tests**
- Ensure correct relative path in `Import-Module`
- Use `$PSScriptRoot` for reliable paths

**GitHub Actions timeout**
- Integration tests may be too slow
- Move to separate workflow or skip in CI

---

## Resources

### Documentation
- [Pester Documentation](https://pester.dev/)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer/blob/master/RuleDocumentation/README.md)
- [PowerShell Gallery Publishing](https://docs.microsoft.com/en-us/powershell/scripting/gallery/how-to/publishing-packages/publishing-a-package)
- [GitHub Actions for PowerShell](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-powershell)

### Tools
- [psake](https://github.com/psake/psake)
- [Invoke-Build](https://github.com/nightroman/Invoke-Build)
- [Pester](https://github.com/pester/Pester)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)

---

## Next Steps When Ready

1. Start with Phase 1 (Repository Setup) - creates foundation
2. Write one simple test - validates testing infrastructure
3. Create basic build script - automates workflow
4. Set up GitHub Actions - enables CI/CD
5. Iterate and improve test coverage
6. Publish first release when confident

Good luck with the publishing process! With Claude Code Pro, you'll be able to iterate quickly on tests and CI/CD configurations.
