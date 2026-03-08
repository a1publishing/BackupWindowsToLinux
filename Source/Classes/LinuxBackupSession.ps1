class LinuxBackupSession {
    # Connection properties
    [string]$Source
    [string]$Destination
    [string]$HostName
    [string]$UserName
    [string]$KeyFile
    [int]$Port
    [string[]]$ExcludePatterns
    [bool]$DryRun
    [bool]$DeleteOrphaned
    [string]$VerbosePreference

    # Internal state
    [string]$sshTarget
    [array]$sshArgs
    [int]$sourceLength
    [hashtable]$remoteIndex
    [hashtable]$createdDirs
    [hashtable]$stats
    [System.Text.Encoding]$previousOutputEncoding

    # Constructor
    LinuxBackupSession(
        [string]$Source,
        [string]$Destination,
        [string]$HostName,
        [string]$UserName,
        [string]$KeyFile,
        [int]$Port,
        [string[]]$ExcludePatterns,
        [bool]$DryRun,
        [bool]$DeleteOrphaned,
        [string]$VerbosePreference
    ) {
        $this.Source = $Source
        $this.Destination = $Destination
        $this.HostName = $HostName
        $this.UserName = $UserName
        $this.KeyFile = $KeyFile
        $this.Port = $Port
        $this.ExcludePatterns = $ExcludePatterns
        $this.DryRun = $DryRun
        $this.DeleteOrphaned = $DeleteOrphaned
        $this.VerbosePreference = $VerbosePreference

        $this.remoteIndex = @{}
        $this.createdDirs = @{}
        $this.stats = @{
            Total = 0
            Uploaded = 0
            Skipped = 0
            Failed = 0
            BytesTransferred = 0
        }
    }

    # Helper method to escape special characters for bash shell
    [string] ConvertToBashEscapedString([string]$InputString) {
        # Escape single quotes by ending quote, adding escaped quote, and starting quote again
        return $InputString -replace "'", "'\\''"
    }

    # Test if OpenSSH client is installed
    [bool] TestOpenSSHClient() {
        $sshExe = Get-Command ssh -ErrorAction SilentlyContinue
        $scpExe = Get-Command scp -ErrorAction SilentlyContinue

        if (-not $sshExe -or -not $scpExe) {
            Write-Error "OpenSSH client not found. Install it via: Settings > Apps > Optional Features > OpenSSH Client"
            Write-Host "Or via PowerShell (as Administrator): Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0" -ForegroundColor Yellow
            return $false
        }
        return $true
    }

    # Validate and normalize the source path
    [bool] ValidateAndNormalizeSource() {
        if (-not (Test-Path $this.Source)) {
            Write-Error "Source path '$($this.Source)' does not exist"
            return $false
        }

        # Normalize paths - handle both local and UNC paths
        $this.Source = (Resolve-Path $this.Source).Path

        # Remove PowerShell provider prefix if present
        if ($this.Source -match '^[^:]+::[A-Z]:\\') {
            $this.Source = $this.Source -replace '^[^:]+::', ''
        }
        elseif ($this.Source -match '^[^:]+::\\\\') {
            $this.Source = $this.Source -replace '^[^:]+::', ''
        }

        # Ensure trailing backslash for consistent string operations
        if (-not $this.Source.EndsWith('\')) {
            $this.Source += '\'
        }

        $this.sourceLength = $this.Source.Length

        if ($this.VerbosePreference -eq 'Continue') {
            Write-Host "Normalized source path: $($this.Source)" -ForegroundColor Gray
            Write-Host "Source length: $($this.sourceLength)" -ForegroundColor Gray
        }

        return $true
    }

    # Normalize the destination path
    [void] NormalizeDestination() {
        $this.Destination = $this.Destination.Replace('\', '/')
        if (-not $this.Destination.EndsWith('/')) {
            $this.Destination += '/'
        }
    }

    # Initialize SSH connection parameters
    [bool] InitializeSSHConnection() {
        $this.sshTarget = "$($this.UserName)@$($this.HostName)"
        $this.sshArgs = @("-p", $this.Port, "-o", "StrictHostKeyChecking=no")

        if ($this.KeyFile) {
            if (-not (Test-Path $this.KeyFile)) {
                Write-Error "Key file not found: $($this.KeyFile)"
                return $false
            }
            $this.sshArgs += @("-i", $this.KeyFile)
            Write-Host "Authentication: SSH key ($($this.KeyFile))" -ForegroundColor Cyan
        }
        else {
            Write-Host "Authentication: Default SSH keys (~/.ssh/id_rsa, id_ed25519, etc.)" -ForegroundColor Cyan
            Write-Host "Note: For automated/scheduled backups, use -KeyFile parameter" -ForegroundColor Yellow
        }

        return $true
    }

    # Test SSH connection to remote host
    [bool] TestSSHConnection() {
        Write-Host "Testing SSH connection..." -ForegroundColor Cyan
        $testCmd = "echo 'Connection successful'"
        $sshTestArgs = $this.sshArgs + @($this.sshTarget, $testCmd)

        try {
            $testResult = & ssh @sshTestArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Error "SSH connection failed: $testResult"
                Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
                Write-Host "  1. Verify hostname/IP is correct and reachable" -ForegroundColor Yellow
                Write-Host "  2. Ensure SSH key is set up: ssh-copy-id $($this.UserName)@$($this.HostName)" -ForegroundColor Yellow
                Write-Host "  3. Test manually: ssh -i `"$($this.KeyFile)`" $($this.UserName)@$($this.HostName)" -ForegroundColor Yellow
                return $false
            }
            Write-Host "Connected successfully!" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Error "SSH connection failed: $_"
            return $false
        }
    }

    # Create the destination directory on remote host
    [void] CreateDestinationDirectory() {
        Write-Host "Verifying destination directory..." -ForegroundColor Cyan
        $escapedDestination = $this.ConvertToBashEscapedString($this.Destination)
        $mkdirCmd = "export LC_ALL=C.UTF-8; mkdir -p '$escapedDestination'"
        $sshMkdirArgs = $this.sshArgs + @($this.sshTarget, $mkdirCmd)
        $null = & ssh @sshMkdirArgs
    }

    # Get list of local files to transfer
    [array] GetLocalFiles() {
        Write-Host "Scanning source files..." -ForegroundColor Cyan
        $localFiles = Get-ChildItem -Path $this.Source -Recurse -File

        if ($this.ExcludePatterns.Count -gt 0) {
            $originalCount = $localFiles.Count

            foreach ($pattern in $this.ExcludePatterns) {
                $localFiles = $localFiles | Where-Object {
                    if ($_.FullName.StartsWith($this.Source, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $relativePath = $_.FullName.Substring($this.sourceLength).Replace('\', '/')
                    }
                    else {
                        $relativePath = ""
                    }

                    $fileNameMatch = $_.Name -like $pattern
                    $pathMatch = $relativePath -like "*/$pattern/*" -or $relativePath -like "$pattern/*" -or $relativePath -like "*/$pattern"
                    $fullPathMatch = $relativePath -like $pattern -or $relativePath -like "*/$pattern"

                    -not ($fileNameMatch -or $pathMatch -or $fullPathMatch)
                }
            }

            $excludedCount = $originalCount - $localFiles.Count
            if ($excludedCount -gt 0) {
                Write-Host "Excluded $excludedCount file(s) based on patterns" -ForegroundColor Yellow
            }
        }

        Write-Host "Found $($localFiles.Count) file(s) to process" -ForegroundColor Cyan
        Write-Host ""

        return $localFiles
    }

    # Build index of remote files
    [void] BuildRemoteIndex() {
        Write-Host "Building remote file index..." -ForegroundColor Cyan
        $this.remoteIndex = @{}

        $escapedDestination = $this.ConvertToBashEscapedString($this.Destination)
        $listCmd = "export LC_ALL=C.UTF-8; find '$escapedDestination' -type f -printf '%P\t%s\t%T@\n' 2>/dev/null || true"
        $sshListArgs = $this.sshArgs + @($this.sshTarget, $listCmd)
        $remoteList = & ssh @sshListArgs

        if ($remoteList) {
            foreach ($line in $remoteList) {
                if ($line -and $line.Trim()) {
                    $parts = $line -split "`t"
                    if ($parts.Count -eq 3) {
                        $this.remoteIndex[$parts[0]] = @{
                            Size = [long]$parts[1]
                            ModTime = [double]$parts[2]
                        }
                    }
                }
            }
        }

        Write-Host "Remote index contains $($this.remoteIndex.Count) file(s)" -ForegroundColor Cyan
        Write-Host ""
    }

    # Check if a file needs to be transferred
    [hashtable] CheckFileNeedsTransfer([System.IO.FileInfo]$file, [string]$relativePath) {
        $needsTransfer = $true
        $reason = "new file"

        if ($this.remoteIndex.ContainsKey($relativePath)) {
            $remoteFile = $this.remoteIndex[$relativePath]

            if ($file.Length -eq $remoteFile.Size) {
                $localModTime = [double]($file.LastWriteTimeUtc - [DateTime]'1970-01-01').TotalSeconds
                if ([Math]::Abs($localModTime - $remoteFile.ModTime) -lt 2) {
                    $needsTransfer = $false
                }
                else {
                    $reason = "modified (time)"
                }
            }
            else {
                $reason = "modified (size)"
            }
        }

        return @{
            NeedsTransfer = $needsTransfer
            Reason = $reason
        }
    }

    # Create a remote directory (cached to avoid redundant calls)
    [void] EnsureRemoteDirectory([string]$remoteDir) {
        if (-not $this.createdDirs.ContainsKey($remoteDir)) {
            if ($this.VerbosePreference -eq 'Continue') {
                Write-Host "  Creating directory: $remoteDir" -ForegroundColor Gray
            }

            $doubleQuoteEscaped = $remoteDir -replace '([\$`"\\])', '\$1'
            $mkdirCmd = "export LC_ALL=C.UTF-8; mkdir -p `"$doubleQuoteEscaped`""
            $sshMkdirArgs = $this.sshArgs + @($this.sshTarget, $mkdirCmd)
            $mkdirResult = & ssh @sshMkdirArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Host "  Warning: mkdir failed for $remoteDir : $mkdirResult" -ForegroundColor Yellow
            }
            else {
                $this.createdDirs[$remoteDir] = $true
            }
        }
    }

    # Upload a file to the remote host
    [bool] UploadFile([System.IO.FileInfo]$file, [string]$remotePath) {
        $uploadSuccess = $false
        $fullCommandLength = $file.FullName.Length + $remotePath.Length + $this.sshTarget.Length + 200
        $useDirectSCP = $fullCommandLength -lt 2000

        if ($useDirectSCP) {
            try {
                $scpArgs = @("-P", $this.Port, "-o", "StrictHostKeyChecking=no")
                if ($this.KeyFile) {
                    $scpArgs += @("-i", $this.KeyFile)
                }
                $scpArgs += @($file.FullName, "$($this.sshTarget):${remotePath}")

                $scpResult = & scp @scpArgs
                if ($LASTEXITCODE -eq 0) {
                    $uploadSuccess = $true
                }
                else {
                    Write-Host "  Direct SCP failed (exit code: $LASTEXITCODE), falling back to temp file method" -ForegroundColor Yellow
                    if ($this.VerbosePreference -eq 'Continue') {
                        Write-Host "  SCP error: $scpResult" -ForegroundColor Gray
                    }
                }
            }
            catch {
                Write-Host "  Direct SCP exception: $_, falling back to temp file method" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "  Path too long ($fullCommandLength chars), using temp file method" -ForegroundColor Yellow
        }

        if (-not $uploadSuccess) {
            Write-Host "  Using temp file method" -ForegroundColor Yellow

            $localTempFile = [System.IO.Path]::GetTempFileName()

            try {
                Copy-Item -Path $file.FullName -Destination $localTempFile -Force

                $remoteTempFile = "/tmp/psbackup_$(Get-Random).tmp"

                $scpTempArgs = @("-P", $this.Port, "-o", "StrictHostKeyChecking=no")
                if ($this.KeyFile) {
                    $scpTempArgs += @("-i", $this.KeyFile)
                }
                $scpTempArgs += @($localTempFile, "$($this.sshTarget):${remoteTempFile}")

                $null = & scp @scpTempArgs

                if ($LASTEXITCODE -eq 0) {
                    $doubleQuoteEscaped = $remotePath -replace '([\$`"\\])', '\$1'
                    $moveCmd = "export LC_ALL=C.UTF-8; mv '$remoteTempFile' `"$doubleQuoteEscaped`""
                    $sshMoveArgs = $this.sshArgs + @($this.sshTarget, $moveCmd)
                    $moveResult = & ssh @sshMoveArgs

                    if ($LASTEXITCODE -eq 0) {
                        $uploadSuccess = $true
                    }
                    else {
                        $rmCmd = "rm -f '$remoteTempFile'"
                        $sshRmArgs = $this.sshArgs + @($this.sshTarget, $rmCmd)
                        $null = & ssh @sshRmArgs

                        Write-Host "  Move failed" -ForegroundColor Red
                        Write-Host "  Remote path: $remotePath" -ForegroundColor Red
                        Write-Host "  Error: $moveResult" -ForegroundColor Red
                        throw "Failed to move temp file to final destination"
                    }
                }
                else {
                    throw "Failed to upload temp file"
                }
            }
            finally {
                if (Test-Path $localTempFile) {
                    Remove-Item $localTempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }

        return $uploadSuccess
    }

    # Set the modification time on the remote file
    [void] SetRemoteModificationTime([System.IO.FileInfo]$file, [string]$remotePath) {
        $doubleQuoteEscaped = $remotePath -replace '([\$`"\\])', '\$1'
        $unixTime = [int64]($file.LastWriteTimeUtc - [DateTime]'1970-01-01').TotalSeconds
        $touchCmd = "export LC_ALL=C.UTF-8; touch -d '@$unixTime' `"$doubleQuoteEscaped`""
        $sshTouchArgs = $this.sshArgs + @($this.sshTarget, $touchCmd)
        $touchResult = & ssh @sshTouchArgs

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Warning: touch failed: $touchResult" -ForegroundColor Yellow
        }
    }

    # Process all files for backup
    [void] ProcessFiles([array]$localFiles) {
        $this.stats.Total = $localFiles.Count

        $counter = 0
        foreach ($file in $localFiles) {
            $counter++

            if ($file.FullName.StartsWith($this.Source, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $file.FullName.Substring($this.sourceLength).Replace('\', '/')
            }
            else {
                Write-Warning "File path doesn't match source path format."
                Write-Warning "  File: $($file.FullName)"
                Write-Warning "  Source: $($this.Source)"
                continue
            }
            $remotePath = $this.Destination + $relativePath

            $lastSlash = $remotePath.LastIndexOf('/')
            if ($lastSlash -gt 0) {
                $remoteDir = $remotePath.Substring(0, $lastSlash)
            }
            else {
                $remoteDir = $this.Destination.TrimEnd('/')
            }

            $transferCheck = $this.CheckFileNeedsTransfer($file, $relativePath)

            $progressPercent = [int](($counter / $this.stats.Total) * 100)
            Write-Progress -Activity "Syncing files" -Status "$counter of $($this.stats.Total)" -PercentComplete $progressPercent

            if ($transferCheck.NeedsTransfer) {
                $fileSizeMB = [math]::Round($file.Length / 1MB, 2)
                Write-Host "[$counter/$($this.stats.Total)] Uploading: $relativePath ($fileSizeMB MB) - $($transferCheck.Reason)" -ForegroundColor Green

                if (-not $this.DryRun) {
                    try {
                        $this.EnsureRemoteDirectory($remoteDir)

                        $uploadSuccess = $this.UploadFile($file, $remotePath)

                        if (-not $uploadSuccess) {
                            throw "File upload failed"
                        }

                        $this.SetRemoteModificationTime($file, $remotePath)

                        $this.stats.Uploaded++
                        $this.stats.BytesTransferred += $file.Length
                    }
                    catch {
                        Write-Host "  ERROR: $_" -ForegroundColor Red
                        $this.stats.Failed++
                    }
                }
                else {
                    $this.stats.Uploaded++
                }
            }
            else {
                if ($this.VerbosePreference -eq 'Continue') {
                    Write-Host "[$counter/$($this.stats.Total)] Skipped: $relativePath (unchanged)" -ForegroundColor Gray
                }
                $this.stats.Skipped++
            }
        }

        Write-Progress -Activity "Syncing files" -Completed
    }

    # Delete orphaned files on remote
    [void] DeleteOrphanedFiles([array]$localFiles) {
        Write-Host "`nChecking for orphaned files on remote..." -ForegroundColor Cyan
        $localRelativePaths = $localFiles | ForEach-Object {
            if ($_.FullName.StartsWith($this.Source, [System.StringComparison]::OrdinalIgnoreCase)) {
                $_.FullName.Substring($this.sourceLength).Replace('\', '/')
            }
        }
        $orphanedFiles = $this.remoteIndex.Keys | Where-Object { $_ -notin $localRelativePaths }

        if ($orphanedFiles.Count -gt 0) {
            Write-Host "Found $($orphanedFiles.Count) orphaned file(s)" -ForegroundColor Yellow

            foreach ($orphan in $orphanedFiles) {
                $remotePath = $this.Destination + $orphan
                Write-Host "Deleting file: $orphan" -ForegroundColor Yellow

                if (-not $this.DryRun) {
                    $doubleQuoteEscaped = $remotePath -replace '([\$`"\\])', '\$1'
                    $rmCmd = "export LC_ALL=C.UTF-8; rm -f `"$doubleQuoteEscaped`""
                    $sshRmArgs = $this.sshArgs + @($this.sshTarget, $rmCmd)
                    $result = & ssh @sshRmArgs

                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "  Warning: Failed to delete $orphan : $result" -ForegroundColor Red
                    }
                }
            }
        }
    }

    # Delete orphaned directories on remote
    [void] DeleteOrphanedDirectories([array]$localFiles) {
        Write-Host "Checking for orphaned directories on remote..." -ForegroundColor Cyan

        $localDirs = Get-ChildItem -Path $this.Source -Recurse -Directory | ForEach-Object {
            if ($_.FullName.StartsWith($this.Source, [System.StringComparison]::OrdinalIgnoreCase)) {
                $_.FullName.Substring($this.sourceLength).Replace('\', '/')
            }
        }

        $escapedDestination = $this.ConvertToBashEscapedString($this.Destination)
        $listDirsCmd = "export LC_ALL=C.UTF-8; find '$escapedDestination' -mindepth 1 -type d -printf '%P\n' 2>/dev/null || true"
        $sshListDirsArgs = $this.sshArgs + @($this.sshTarget, $listDirsCmd)
        $remoteDirs = & ssh @sshListDirsArgs

        if ($remoteDirs) {
            $orphanedDirs = @()
            foreach ($remoteDir in $remoteDirs) {
                $remoteDir = $remoteDir.Trim()
                if ($remoteDir -and ($remoteDir -notin $localDirs)) {
                    $orphanedDirs += $remoteDir
                }
            }

            if ($orphanedDirs.Count -gt 0) {
                Write-Host "Found $($orphanedDirs.Count) orphaned director(ies)" -ForegroundColor Yellow

                $orphanedDirs = $orphanedDirs | Sort-Object { ($_ -split '/').Count } -Descending

                foreach ($orphanDir in $orphanedDirs) {
                    $remoteDirPath = $this.Destination + $orphanDir
                    Write-Host "Deleting directory: $orphanDir" -ForegroundColor Yellow

                    if (-not $this.DryRun) {
                        $doubleQuoteEscaped = $remoteDirPath -replace '([\$`"\\])', '\$1'
                        $rmCmd = "export LC_ALL=C.UTF-8; rm -rf `"$doubleQuoteEscaped`""
                        $sshRmArgs = $this.sshArgs + @($this.sshTarget, $rmCmd)
                        $result = & ssh @sshRmArgs

                        if ($LASTEXITCODE -ne 0) {
                            Write-Host "  Warning: Failed to delete directory $orphanDir : $result" -ForegroundColor Red
                        }
                    }
                }
            }
        }
    }

    # Display configuration summary
    [void] ShowConfiguration() {
        Write-Host "=== Backup Configuration ===" -ForegroundColor Cyan
        Write-Host "Source:      $($this.Source)"
        Write-Host "Destination: $($this.HostName):$($this.Destination)"
        Write-Host "User:        $($this.UserName)"
        Write-Host "Port:        $($this.Port)"
        if ($this.DryRun) {
            Write-Host "Mode:        DRY RUN (no files will be transferred)" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Display summary statistics
    [void] ShowSummary() {
        Write-Host "`n=== Backup Summary ===" -ForegroundColor Cyan
        Write-Host "Total files:       $($this.stats.Total)"
        Write-Host "Uploaded:          $($this.stats.Uploaded)" -ForegroundColor Green
        Write-Host "Skipped:           $($this.stats.Skipped)" -ForegroundColor Gray
        Write-Host "Failed:            $($this.stats.Failed)" -ForegroundColor $(if ($this.stats.Failed -gt 0) { 'Red' } else { 'Gray' })
        Write-Host "Data transferred:  $([math]::Round($this.stats.BytesTransferred / 1MB, 2)) MB"

        if ($this.DryRun) {
            Write-Host "`nThis was a DRY RUN - no files were actually transferred" -ForegroundColor Yellow
        }
    }

    # Main execution method
    [void] Execute() {
        $this.previousOutputEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        try {
            if (-not $this.TestOpenSSHClient()) { return }
            if (-not $this.ValidateAndNormalizeSource()) { return }

            $this.NormalizeDestination()
            $this.ShowConfiguration()

            if (-not $this.InitializeSSHConnection()) { return }
            if (-not $this.TestSSHConnection()) { return }

            $this.CreateDestinationDirectory()

            $localFiles = $this.GetLocalFiles()
            $this.BuildRemoteIndex()

            $this.ProcessFiles($localFiles)

            if ($this.DeleteOrphaned) {
                $this.DeleteOrphanedFiles($localFiles)
                $this.DeleteOrphanedDirectories($localFiles)
            }

            $this.ShowSummary()
        }
        finally {
            [Console]::OutputEncoding = $this.previousOutputEncoding
        }
    }
}
