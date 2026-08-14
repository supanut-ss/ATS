#Requires -Version 5.1
<#
.SYNOPSIS
    FTP utility library. Dot-source this file to load functions.
    (ไลบรารีสำหรับจัดการ FTP/FTPS - ใช้สำหรับ include เข้าไปในสคริปต์อื่น)
    Usage: . "$PSScriptRoot\upload-ftp.ps1"

.NOTES
    รองรับการเชื่อมต่อแบบ FTP ปกติ และ FTPS (Explicit TLS)
    * ไม่รองรับ SFTP (หากต้องการใช้ SFTP ต้องพึ่งพาเครื่องมืออื่นเช่น WinSCP หรือ Posh-SSH)

    ข้อจำกัดของการใช้ FTP บน Shared Hosting ทั่วไป:
      - ไม่สามารถเขียนทับไฟล์แบบ Atomic ได้ 100% จึงต้องใช้วิธีเปลี่ยนชื่อ (Rename)
      - ฟังก์ชันการเช็ค Lock อาจมี Race condition เล็กน้อยเนื่องจากข้อจำกัดของ Protocol
#>

# -- Connection state (module-level) ------------------------------------------
$script:FtpConn = @{
    Server   = [string]""
    User     = [string]""
    Password = [string]""
    UseTls   = $false
}

# -----------------------------------------------------------------------------
# Public: Initialize-FtpConnection
# -----------------------------------------------------------------------------
function Initialize-FtpConnection {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Password,
        [switch]$UseTls
    )
    $script:FtpConn.Server   = $Server.Trim()
    $script:FtpConn.User     = $Username
    $script:FtpConn.Password = $Password
    $script:FtpConn.UseTls   = $UseTls.IsPresent
}

# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
function ConvertTo-FtpUri ([string]$RemotePath) {
    $p = $RemotePath.Replace('\', '/').TrimStart('/')
    while ($p.Contains('//')) { $p = $p.Replace('//', '/') }
    return "ftp://$($script:FtpConn.Server)/$p"
}

function New-FtpRequest {
    param(
        [string]$Uri,
        [string]$Method,
        [int]$TimeoutMs      = 60000,
        [int]$ReadWriteMs    = 180000
    )
    $req = [System.Net.FtpWebRequest]::Create($Uri)
    $req.Method           = $Method
    $req.Credentials      = [System.Net.NetworkCredential]::new($script:FtpConn.User, $script:FtpConn.Password)
    $req.UsePassive       = $true
    $req.UseBinary        = $true
    $req.KeepAlive        = $false
    $req.Timeout          = $TimeoutMs
    $req.ReadWriteTimeout = $ReadWriteMs
    if ($script:FtpConn.UseTls) { $req.EnableSsl = $true }
    return $req
}

function Get-FtpStatusCode ($err) {
    $ex = if ($err -is [System.Management.Automation.ErrorRecord]) { $err.Exception } else { $err }
    if ($ex -is [System.Net.WebException] -and $ex.Response) {
        $sc = [int]$ex.Response.StatusCode
        $ex.Response.Close()
        return $sc
    }
    return -1
}

# -----------------------------------------------------------------------------
# Public: Existence checks
# -----------------------------------------------------------------------------
function Test-FtpFileExists ([string]$RemotePath) {
    try {
        $req  = New-FtpRequest (ConvertTo-FtpUri $RemotePath) ([System.Net.WebRequestMethods+Ftp]::GetFileSize)
        $resp = $req.GetResponse(); $resp.Close()
        return $true
    } catch { return $false }
}

function Test-FtpDirectoryExists ([string]$RemotePath) {
    try {
        $uri  = ConvertTo-FtpUri ($RemotePath.TrimEnd('/') + '/')
        $req  = New-FtpRequest $uri ([System.Net.WebRequestMethods+Ftp]::ListDirectory)
        $resp = $req.GetResponse(); $resp.Close()
        return $true
    } catch { return $false }
}

# -----------------------------------------------------------------------------
# Public: Directory creation (creates each segment, ignores 550 = already exists)
# -----------------------------------------------------------------------------
function Ensure-FtpDirectory ([string]$RemotePath) {
    if ([string]::IsNullOrWhiteSpace($RemotePath)) { return }
    $parts = $RemotePath.Trim('/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
    $cur   = ""
    foreach ($part in $parts) {
        $cur = if ($cur) { "$cur/$part" } else { $part }
        try {
            $req  = New-FtpRequest (ConvertTo-FtpUri $cur) ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
            $resp = $req.GetResponse(); $resp.Close()
        } catch [System.Net.WebException] {
            $sc = Get-FtpStatusCode $_
            if ($sc -eq 550) { continue }    # already exists -- ok
            if (Test-FtpDirectoryExists $cur) { continue }
            throw
        }
    }
}

# -----------------------------------------------------------------------------
# Public: Download file as UTF-8 string  (returns null when 550 Not Found)
# -----------------------------------------------------------------------------
function Get-FtpFileContent ([string]$RemotePath) {
    try {
        $req    = New-FtpRequest (ConvertTo-FtpUri $RemotePath) ([System.Net.WebRequestMethods+Ftp]::DownloadFile)
        $resp   = $req.GetResponse()
        $reader = [System.IO.StreamReader]::new($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $text   = $reader.ReadToEnd()
        $reader.Close(); $resp.Close()
        return $text
    } catch [System.Net.WebException] {
        $sc = Get-FtpStatusCode $_
        if ($sc -eq 550) { return $null }    # file not found
        throw
    }
}

# -----------------------------------------------------------------------------
# Public: Upload raw bytes (with retry + backoff)
# -----------------------------------------------------------------------------
function Invoke-FtpUploadBytes {
    param(
        [Parameter(Mandatory)][string]$RemotePath,
        [Parameter(Mandatory)][byte[]]$Bytes,
        [int]$MaxAttempts = 3
    )
    $uri = ConvertTo-FtpUri $RemotePath
    $dir = ($RemotePath -replace '/[^/]+$', '').TrimEnd('/')
    if ($dir -and ($dir -ne $RemotePath)) { Ensure-FtpDirectory $dir }

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            $req = New-FtpRequest $uri ([System.Net.WebRequestMethods+Ftp]::UploadFile)
            $req.ContentLength = $Bytes.Length
            $s = $req.GetRequestStream()
            $s.Write($Bytes, 0, $Bytes.Length)
            $s.Close()
            $resp = $req.GetResponse(); $resp.Close()
            return
        } catch [System.Net.WebException] {
            if ($i -lt $MaxAttempts) {
                $delay = $i * 3
                Write-Warning "FTP upload attempt $i/$MaxAttempts failed: $($_.Exception.Message) -- retry in ${delay}s"
                try { Invoke-FtpDelete $RemotePath } catch { }
                Start-Sleep $delay
                continue
            }
            throw
        } catch {
            if ($i -lt $MaxAttempts) {
                $delay = $i * 3
                Write-Warning "FTP upload attempt $i/$MaxAttempts failed: $($_.Exception.Message) -- retry in ${delay}s"
                try { Invoke-FtpDelete $RemotePath } catch { }
                Start-Sleep $delay
                continue
            }
            throw
        }
    }
}

# -----------------------------------------------------------------------------
# Public: Upload local file
# -----------------------------------------------------------------------------
function Invoke-FtpUploadFile ([string]$LocalPath, [string]$RemotePath, [int]$MaxAttempts = 3) {
    Invoke-FtpUploadBytes -RemotePath $RemotePath -Bytes ([System.IO.File]::ReadAllBytes($LocalPath)) -MaxAttempts $MaxAttempts
}

# -----------------------------------------------------------------------------
# Public: Upload UTF-8 string as a file
# -----------------------------------------------------------------------------
function Invoke-FtpUploadText ([string]$RemotePath, [string]$Content) {
    Invoke-FtpUploadBytes -RemotePath $RemotePath -Bytes ([System.Text.Encoding]::UTF8.GetBytes($Content))
}

# -----------------------------------------------------------------------------
# Public: Rename (RNFR/RNTO) -- NewName is just the filename (same directory)
# -----------------------------------------------------------------------------
function Invoke-FtpRename ([string]$OldPath, [string]$NewName) {
    $req = New-FtpRequest (ConvertTo-FtpUri $OldPath) ([System.Net.WebRequestMethods+Ftp]::Rename)
    $req.RenameTo = $NewName
    $resp = $req.GetResponse(); $resp.Close()
}

# -----------------------------------------------------------------------------
# Public: Delete file (silently ignores 550 = already gone)
# -----------------------------------------------------------------------------
function Invoke-FtpDelete ([string]$RemotePath) {
    try {
        $req  = New-FtpRequest (ConvertTo-FtpUri $RemotePath) ([System.Net.WebRequestMethods+Ftp]::DeleteFile)
        $resp = $req.GetResponse(); $resp.Close()
    } catch [System.Net.WebException] {
        $sc = Get-FtpStatusCode $_
        if ($sc -eq 550) { return }    # already gone -- that's fine
        throw
    }
}

# -----------------------------------------------------------------------------
# Public: Atomic-ish upload  (upload as .uploading -> delete old -> rename)
#   If rename fails: fall back to direct overwrite (logs a warning).
# -----------------------------------------------------------------------------
function Invoke-FtpUploadFileAtomic {
    param(
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$RemotePath,
        [int]$MaxAttempts = 3
    )
    $tempPath  = "$RemotePath.uploading"
    $finalName = [System.IO.Path]::GetFileName($RemotePath)

    Invoke-FtpUploadFile -LocalPath $LocalPath -RemotePath $tempPath -MaxAttempts $MaxAttempts
    Invoke-FtpDelete $RemotePath
    try {
        Invoke-FtpRename -OldPath $tempPath -NewName $finalName
    } catch {
        Write-Warning "RNTO rename failed for '$RemotePath' ($($_.Exception.Message)) -- falling back to direct upload."
        try { Invoke-FtpDelete $tempPath } catch { }
        Invoke-FtpUploadFile -LocalPath $LocalPath -RemotePath $RemotePath -MaxAttempts $MaxAttempts
    }
}
