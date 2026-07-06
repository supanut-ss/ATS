param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$Username,

    [Parameter(Mandatory = $true)]
    [string]$Password,

    [Parameter(Mandatory = $true)]
    [string]$LocalPath,

    [Parameter(Mandatory = $false)]
    [string]$RemotePath = "",

    [string[]]$ExcludePaths = @(),

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function New-FtpRequest {
    param(
        [string]$Uri,
        [string]$Method
    )

    $request = [System.Net.FtpWebRequest]::Create($Uri)
    $request.Method = $Method
    $request.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
    $request.UsePassive = $true
    $request.UseBinary = $true
    $request.KeepAlive = $false
    $request.Timeout = 30000
    $request.ReadWriteTimeout = 120000
    return $request
}

function Test-RemoteDirectoryExists {
    param([string]$DirectoryPath)

    if ([string]::IsNullOrWhiteSpace($DirectoryPath)) {
        return $true
    }

    $uri = "ftp://$Server/$($DirectoryPath.Trim('/'))/"

    try {
        $request = New-FtpRequest -Uri $uri -Method ([System.Net.WebRequestMethods+Ftp]::ListDirectory)
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Ensure-RemoteDirectory {
    param([string]$DirectoryPath)

    if ([string]::IsNullOrWhiteSpace($DirectoryPath)) {
        return
    }

    $parts = $DirectoryPath.Trim('/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
    $current = ""

    foreach ($part in $parts) {
        if ($current) {
            $current = "$current/$part"
        }
        else {
            $current = $part
        }

        $uri = "ftp://$Server/$current"
        if ($DryRun) {
            continue
        }

        try {
            $request = New-FtpRequest -Uri $uri -Method ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
            $response = $request.GetResponse()
            $response.Close()
            Write-Host "Created Directory: $current" -ForegroundColor Gray
        }
        catch [System.Net.WebException] {
            $ftpResponse = $_.Exception.Response
            if ($ftpResponse) {
                $statusCode = [int]$ftpResponse.StatusCode
                $ftpResponse.Close()

                if ($statusCode -eq [int][System.Net.FtpStatusCode]::ActionNotTakenFileUnavailable) {
                    continue
                }
            }
            if (Test-RemoteDirectoryExists -DirectoryPath $current) {
                continue
            }
            throw "Failed to create remote directory '$current': $($_.Exception.Message)"
        }
    }
}

function Upload-File {
    param(
        [string]$SourceFile,
        [string]$RelativePath
    )

    $remoteFilePath = "$RemotePath/$RelativePath".Replace('\', '/')
    while ($remoteFilePath.Contains("//")) { $remoteFilePath = $remoteFilePath.Replace("//", "/") }
    $remoteFilePath = $remoteFilePath.TrimStart('/')
    
    $remoteDirectory = (Split-Path $remoteFilePath -Parent).Replace('\', '/')
    $remoteUri = "ftp://$Server/$remoteFilePath"
    
    try {
        # Check size of remote file to skip if unchanged
        $request = New-FtpRequest -Uri $remoteUri -Method ([System.Net.WebRequestMethods+Ftp]::GetFileSize)
        $response = $request.GetResponse()
        $remoteSize = $response.ContentLength
        $response.Close()

        $localSize = (Get-Item $SourceFile).Length
        $shouldAlwaysUpload = $RelativePath.EndsWith(".html", [System.StringComparison]::OrdinalIgnoreCase) -or 
                              $RelativePath.EndsWith(".htm", [System.StringComparison]::OrdinalIgnoreCase) -or
                              $RelativePath.EndsWith(".dll", [System.StringComparison]::OrdinalIgnoreCase) -or
                              $RelativePath.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase) -or
                              $RelativePath.EndsWith(".json", [System.StringComparison]::OrdinalIgnoreCase)

        if (-not $shouldAlwaysUpload -and $remoteSize -eq $localSize) {
            Write-Host "Skipped (Size Match): $RelativePath" -ForegroundColor Gray
            return
        }
    }
    catch {
        # File doesn't exist, proceed with upload
    }

    Ensure-RemoteDirectory -DirectoryPath $remoteDirectory

    if ($DryRun) {
        Write-Host "[DryRun] Upload: $RelativePath"
        return
    }

    $fileBytes = [System.IO.File]::ReadAllBytes($SourceFile)

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $request = New-FtpRequest -Uri $remoteUri -Method ([System.Net.WebRequestMethods+Ftp]::UploadFile)
            $request.ContentLength = $fileBytes.Length

            $stream = $request.GetRequestStream()
            $stream.Write($fileBytes, 0, $fileBytes.Length)
            $stream.Close()

            $response = $request.GetResponse()
            $response.Close()

            Write-Host "Uploaded: $RelativePath"
            return
        }
        catch [System.Net.WebException] {
            $statusCode = $null
            $ftpResponse = $_.Exception.Response
            if ($ftpResponse) {
                $statusCode = [int]$ftpResponse.StatusCode
                $ftpResponse.Close()
            }

            if ($attempt -eq 1 -and $statusCode -eq [int][System.Net.FtpStatusCode]::ActionNotTakenFileUnavailable) {
                try {
                    $deleteRequest = New-FtpRequest -Uri $remoteUri -Method ([System.Net.WebRequestMethods+Ftp]::DeleteFile)
                    $deleteResponse = $deleteRequest.GetResponse()
                    $deleteResponse.Close()
                    Write-Host "Retrying after delete: $RelativePath"
                    continue
                }
                catch {
                }
            }

            if ($statusCode -eq [int][System.Net.FtpStatusCode]::ActionNotTakenFileUnavailable) {
                Write-Warning "SKIPPED: Upload failed (550 File Unavailable). The file might be in use or protected: $RelativePath"
                return
            }

            throw "Upload failed for '$RelativePath' -> '$remoteUri': $($_.Exception.Message)"
        }
        catch {
            throw "Upload failed for '$RelativePath' -> '$remoteUri': $($_.Exception.Message)"
        }
    }
}

$resolvedLocal = (Resolve-Path $LocalPath).Path
if (-not (Test-Path $resolvedLocal)) {
    throw "LocalPath not found: $LocalPath"
}

$files = Get-ChildItem -Path $resolvedLocal -Recurse -File | Sort-Object FullName

if (-not $files) {
    throw "No files found in LocalPath: $resolvedLocal"
}

$excluded = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $ExcludePaths) {
    if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $normalized = $entry.Trim().TrimStart('.') -replace '^[\\/]+', ''
        [void]$excluded.Add($normalized.Replace('\', '/'))
    }
}

Write-Host "Local Base Path: $resolvedLocal"
Write-Host "Uploading $($files.Count) files from '$resolvedLocal' to 'ftp://$Server/$RemotePath'"
if ($DryRun) {
    Write-Host "DryRun is enabled. No remote changes will be made."
}

$uploaded = 0
$skipped = 0

foreach ($file in $files) {
    $relative = $file.FullName
    if ($relative.StartsWith($resolvedLocal, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $relative.Substring($resolvedLocal.Length).TrimStart('\').TrimStart('/')
    }
    $relative = $relative.Replace('\', '/')

    $shouldSkip = $false
    foreach ($ex in $excluded) {
        if ($relative.Equals($ex, [System.StringComparison]::OrdinalIgnoreCase) -or
            $relative.StartsWith("$ex/", [System.StringComparison]::OrdinalIgnoreCase)) {
            $shouldSkip = $true
            break
        }
    }

    if ($shouldSkip) {
        $skipped++
        Write-Host "Excluded: $relative"
        continue
    }

    Upload-File -SourceFile $file.FullName -RelativePath $relative
    $uploaded++
}

Write-Host "Upload complete. Uploaded/Checked: $uploaded, Excluded: $skipped"
