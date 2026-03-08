@{
    Path                   = "BackupWindowsToLinux.psd1"
    OutputDirectory        = "..\bin\BackupWindowsToLinux"
    Prefix                 = '.\_PrefixCode.ps1'
    SourceDirectories      = 'Classes', 'Private', 'Public'
    PublicFilter           = 'Public\*.ps1'
    VersionedOutputDirectory = $true
}
