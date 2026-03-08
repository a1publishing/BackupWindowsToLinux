# Changelog

All notable changes to BackupWindowsToLinux are documented here.

## [2.0.0] — 2026-03-08

### Changed
- Renamed module from `BackupToLinux` to `BackupWindowsToLinux`
- Restructured source into `Source/Classes`, `Source/Public`, `Source/Private`
- Added InvokeBuild build system and ModuleBuilder compilation
- Added Pester 5 test suite
- Added MIT licence
- Updated manifest: Author, CompanyName, Tags, LicenseUri, ProjectUri
- Published to PowerShell Gallery

### Added (from v1.x)
- Native OpenSSH support (Windows 10+) — removed Posh-SSH dependency
- Full UTF-8 support for special characters (£, €, etc.)
- Support for long filenames (600+ characters)
- Support for UNC paths
- Automatic fallback for complex paths (temp-file SCP method)
- Improved error handling and reporting
- Directory exclusion patterns
- Orphaned file and directory cleanup
