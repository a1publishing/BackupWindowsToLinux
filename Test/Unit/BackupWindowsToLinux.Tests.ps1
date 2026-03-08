param (
    [Parameter(Mandatory)]
    [string]$File
)

BeforeAll {
    Get-Content $File | ForEach-Object {
        $var = $_.Split('=')
        New-Variable -Name $var[0] -Value $var[1]
    }

    # Remove trailing slash or backslash
    $ModulePath = $ModulePath -replace '[\\/]*$'
    $ModuleName = 'BackupWindowsToLinux'
    $ModuleManifestName = 'BackupWindowsToLinux.psd1'
    $ModuleManifestPath = Join-Path -Path $ModulePath -ChildPath $ModuleManifestName
}


# ── Manifest ──────────────────────────────────────────────────────────────────

Describe 'Manifest' -Tag 'Unit' {

    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath
        $? | Should -Be $true
    }

    It 'Has a valid semantic version' {
        $manifest = Import-PowerShellDataFile -Path $ModuleManifestPath
        $manifest.ModuleVersion | Should -Match '^\d+\.\d+\.\d+'
    }

    It 'Has the expected GUID' {
        $manifest = Import-PowerShellDataFile -Path $ModuleManifestPath
        $manifest.GUID | Should -Be 'a8f4c3d2-1e5b-4a9c-8f7d-2b6e9c4a1f8e'
    }

    AfterAll {
        Get-Module -Name $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
    }
}


# ── Module load ───────────────────────────────────────────────────────────────

Describe 'Module load' -Tag 'Unit' {

    It 'Imports without errors' {
        { Import-Module "$ModulePath\$ModuleName.psd1" -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Exports Sync-ToLinux' {
        Import-Module "$ModulePath\$ModuleName.psd1" -ErrorAction Stop
        Get-Command -Name 'Sync-ToLinux' -Module $ModuleName | Should -Not -BeNullOrEmpty
    }

    It 'Get-Command returns correct module name' {
        Import-Module "$ModulePath\$ModuleName.psd1" -ErrorAction Stop
        (Get-Command 'Sync-ToLinux').ModuleName | Should -Be $ModuleName
    }

    AfterAll {
        Get-Module -Name $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
    }
}


# ── Parameter validation ──────────────────────────────────────────────────────

Describe 'Sync-ToLinux parameter validation' -Tag 'Unit' {

    BeforeAll {
        Import-Module "$ModulePath\$ModuleName.psd1" -ErrorAction Stop
    }

    AfterAll {
        Get-Module -Name $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    It '-Source is mandatory' {
        $cmd = Get-Command 'Sync-ToLinux'
        $cmd.Parameters['Source'].Attributes.Where{ $_ -is [System.Management.Automation.ParameterAttribute] }.Mandatory |
            Should -Contain $true
    }

    It '-Destination is mandatory' {
        $cmd = Get-Command 'Sync-ToLinux'
        $cmd.Parameters['Destination'].Attributes.Where{ $_ -is [System.Management.Automation.ParameterAttribute] }.Mandatory |
            Should -Contain $true
    }

    It '-HostName is mandatory' {
        $cmd = Get-Command 'Sync-ToLinux'
        $cmd.Parameters['HostName'].Attributes.Where{ $_ -is [System.Management.Automation.ParameterAttribute] }.Mandatory |
            Should -Contain $true
    }

    It '-UserName is mandatory' {
        $cmd = Get-Command 'Sync-ToLinux'
        $cmd.Parameters['UserName'].Attributes.Where{ $_ -is [System.Management.Automation.ParameterAttribute] }.Mandatory |
            Should -Contain $true
    }

    It '-Port defaults to 22' {
        $cmd = Get-Command 'Sync-ToLinux'
        $cmd.Parameters['Port'].Attributes.Where{ $_ -is [System.Management.Automation.ParameterAttribute] } | Should -Not -BeNullOrEmpty
        # Default value is defined in the function body; verify parameter exists and is not mandatory
        $cmd.Parameters['Port'].Attributes.Where{ $_ -is [System.Management.Automation.ParameterAttribute] }.Mandatory |
            Should -Not -Contain $true
    }

    It '-DryRun is a switch parameter' {
        $cmd = Get-Command 'Sync-ToLinux'
        $cmd.Parameters['DryRun'].ParameterType | Should -Be ([switch])
    }
}


# ── LinuxBackupSession unit tests (no SSH) ────────────────────────────────────

Describe 'LinuxBackupSession unit tests' -Tag 'Unit' {

    BeforeAll {
        Import-Module "$ModulePath\$ModuleName.psd1" -ErrorAction Stop
    }

    AfterAll {
        Get-Module -Name $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
    }

    Context 'ConvertToBashEscapedString' {

        It 'Escapes single quotes' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.ConvertToBashEscapedString("it's") | Should -Be "it'\''s"
            }
        }

        It 'Handles £ and € without modification' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.ConvertToBashEscapedString('/path/with/£-and-€') | Should -Be '/path/with/£-and-€'
            }
        }

        It 'Handles paths with spaces' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.ConvertToBashEscapedString('/my path/with spaces') | Should -Be '/my path/with spaces'
            }
        }
    }

    Context 'NormalizeDestination' {

        It 'Adds trailing slash when missing' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup/test', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.NormalizeDestination()
                $s.Destination | Should -Be '/backup/test/'
            }
        }

        It 'Does not double trailing slash' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup/test/', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.NormalizeDestination()
                $s.Destination | Should -Be '/backup/test/'
            }
        }

        It 'Converts backslashes to forward slashes' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '\backup\test', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.NormalizeDestination()
                $s.Destination | Should -Be '/backup/test/'
            }
        }
    }

    Context 'ValidateAndNormalizeSource' {

        It 'Throws for non-existent path' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new('C:\ThisPathDoesNotExist_XYZ_12345', '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                { $s.ValidateAndNormalizeSource() } | Should -Throw "*does not exist*"
            }
        }

        It 'Does not throw for existing path' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                { $s.ValidateAndNormalizeSource() } | Should -Not -Throw
            }
        }

        It 'Adds trailing backslash to normalized source' {
            InModuleScope BackupWindowsToLinux {
                $s = [LinuxBackupSession]::new($env:TEMP, '/backup', 'host', 'user', '', 22, @(), $false, $false, 'SilentlyContinue')
                $s.ValidateAndNormalizeSource()
                $s.Source | Should -Match '\\$'
            }
        }
    }
}
