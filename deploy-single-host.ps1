#Requires -Version 5.1
<#
.SYNOPSIS
    สคริปต์สำหรับ Deploy ระบบ ATS (Frontend + Backend) ไปยัง Shared Hosting ผ่าน FTP/FTPS
    (คู่มือการใช้งานภาษาไทย)

.DESCRIPTION
    สคริปต์นี้ถูกออกแบบมาเพื่อการ Deploy ที่ปลอดภัย รองรับการทำงานเป็นทีม (หลายคน Deploy สลับกัน)
    โดยมีขั้นตอนการทำงานดังนี้:
      1. Build ระบบ: คอมไพล์ Frontend (npm run build) และ Backend (dotnet publish)
      2. Lock Server: สร้างไฟล์ Lock เพื่อป้องกันไม่ให้คนอื่นกด Deploy ชนกัน
      3. โหลด Manifest: เช็คสถานะไฟล์ปัจจุบันบนเซิร์ฟเวอร์ (Source of Truth)
      4. ตรวจสอบไฟล์: หาเฉพาะไฟล์ที่เพิ่มใหม่, เปลี่ยนแปลง (SHA-256) หรือถูกลบ
      5. อัปโหลดแบบปลอดภัย: อัปโหลดเป็นชื่อชั่วคราว (.uploading) แล้ว Rename เปลี่ยนชื่อ (ลดโอกาสไฟล์พัง)
      6. ลบไฟล์เก่า: ลบไฟล์ที่ไม่มีอยู่ใน Source code แล้ว (โดยข้ามไฟล์ในหมวด Protected)
      7. บันทึกข้อมูล: อัปเดต Manifest กลับขึ้นไปบนเซิร์ฟเวอร์
      8. นำระบบขึ้น: ลบ Lock และนำหน้า "กำลังอัปเดตระบบ" ออก

    ระบบรักษาความปลอดภัย (Protected Paths):
      สคริปต์จะไม่ลบหรือเขียนทับไฟล์/โฟลเดอร์ต่อไปนี้โดยเด็ดขาด:
      .env, uploads/, storage/, logs/, sessions/, cache/, ไฟล์ฐานข้อมูล (*.db, *.sqlite ฯลฯ)

.PARAMETER Server
    ไอพี หรือ โดเมนของ FTP เซิร์ฟเวอร์ (หากไม่ระบุ จะอ่านจากตัวแปรแวดล้อม FTP_SERVER)

.PARAMETER Username
    ชื่อผู้ใช้งาน FTP (หากไม่ระบุ จะอ่านจากตัวแปรแวดล้อม FTP_USER)

.PARAMETER Password
    รหัสผ่าน FTP (ห้ามเซฟรหัสผ่านลงในโค้ด ให้อ่านจากตัวแปรแวดล้อม FTP_PASS เท่านั้น)

.PARAMETER RemotePath
    Path ปลายทางบน FTP (หากไม่ระบุ จะอ่านจาก FTP_REMOTE ถ้าไม่มีจะใช้ค่าเริ่มต้น ats.thaipesleague.com)

.PARAMETER UseTls
    (แนะนำ) เปิดใช้งาน FTPS (FTP over TLS) เพื่อเข้ารหัสข้อมูลระหว่างอัปโหลด

.PARAMETER DryRun
    โหมดทดสอบ: จำลองการอัปโหลดและลบไฟล์ทั้งหมด เพื่อดูว่ามีไฟล์ไหนจะถูกแก้ไขบ้าง โดยไม่แก้ไขข้อมูลบนเซิร์ฟเวอร์จริง

.PARAMETER ForceUnlock
    บังคับลบ Lock ที่ค้างอยู่บนเซิร์ฟเวอร์ (ใช้เฉพาะกรณีที่มั่นใจว่าไม่มีใครกำลัง Deploy อยู่ แต่ Lock ค้างจากครั้งก่อนที่รันไม่จบ)

.PARAMETER LockTimeoutMinutes
    ระยะเวลาที่ถือว่า Lock นั้นหมดอายุ (ค่าเริ่มต้น: 15 นาที)

.PARAMETER SkipBuild
    ข้ามขั้นตอนการ Build ทันที (เหมาะสำหรับการกด Deploy ซ้ำโดยใช้ไฟล์ที่ Build ไว้แล้วในโฟลเดอร์ deploy/)

.EXAMPLE
    # ขั้นตอนที่ 1: กำหนดรหัสผ่านใน Environment (ทำครั้งเดียวตอนเปิดหน้าจอ Terminal)
    $env:FTP_SERVER = "94.237.76.153"
    $env:FTP_USER   = "thaipes"
    $env:FTP_PASS   = "Ws7#3es2"
    $env:FTP_REMOTE = "ats.thaipesleague.com"

    # ขั้นตอนที่ 2: รันแบบทดสอบ (เพื่อดูว่ามีไฟล์อะไรจะอัปเดตบ้าง โดยไม่กระทบของจริง)
    .\deploy-single-host.ps1 -DryRun

    # ขั้นตอนที่ 3: รันเพื่ออัปโหลดขึ้น Production จริง
    .\deploy-single-host.ps1

    # กรณี Lock ค้าง (มี Error ก่อนหน้ารันไม่จบ)
    .\deploy-single-host.ps1 -ForceUnlock
#>
param(
    [string]$Server = $env:FTP_SERVER,
    [string]$Username = $env:FTP_USER,
    [string]$Password = $env:FTP_PASS,
    [string]$RemotePath = $env:FTP_REMOTE,
    [switch]$UseTls,
    [switch]$DryRun,
    [switch]$ForceUnlock,
    [switch]$SkipBuild,
    [int]$LockTimeoutMinutes = 15
)

$ErrorActionPreference = "Stop"

if (-not $RemotePath) { $RemotePath = "ats.thaipesleague.com" }
$RemotePath = $RemotePath.Replace('\', '/').TrimEnd('/')

$repoRoot = $PSScriptRoot
$BACKEND_LOCAL = "$repoRoot\deploy\backend"
$LOCK_REMOTE = "$RemotePath/.deploy-lock"
$MANIFEST_REMOTE = "$RemotePath/.deploy-manifest.json"
$OFFLINE_REMOTE = "$RemotePath/app_offline.htm"

. "$repoRoot\upload-ftp.ps1"

# Files/directories that must NEVER be deleted or overwritten by this script.
# Patterns: exact name, glob (with *), or prefix ending with / for directories.
$PROTECTED = @(
    ".env", ".env.*",
    "uploads/", "storage/", "logs/", "sessions/", "cache/",
    "*.db", "*.sqlite", "*.mdf", "*.ldf",
    ".deploy-manifest.json", ".deploy-lock"
)

# --- Logging -----------------------------------------------------------------
function Write-Log ([string]$Level, [string]$Msg, [ConsoleColor]$Color = "White") {
    Write-Host "$(Get-Date -Format 'HH:mm:ss') [$Level] $Msg" -ForegroundColor $Color
}
function Write-Step  ([string]$m) { Write-Log STEP  $m Yellow }
function Write-Ok    ([string]$m) { Write-Log OK    $m Green }
function Write-Info  ([string]$m) { Write-Log INFO  $m Gray }
function Write-Warn  ([string]$m) { Write-Log WARN  $m DarkYellow }
function Write-Err   ([string]$m) { Write-Log ERROR $m Red }
function Write-Dry   ([string]$m) { Write-Log DRY   $m Cyan }

# --- Protected path check ----------------------------------------------------
function Test-ProtectedPath ([string]$RelPath) {
    $rp = $RelPath.Replace('\', '/').TrimStart('/')
    foreach ($pat in $PROTECTED) {
        if ($pat.EndsWith('/')) {
            if ($rp -eq $pat.TrimEnd('/') -or
                $rp.StartsWith($pat, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        elseif ($pat.Contains('*')) {
            if ($rp -like $pat) { return $true }
        }
        else {
            if ($rp -ieq $pat -or
                $rp.StartsWith("$pat/", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    }
    return $false
}

# --- State tracking (for cleanup on error) -----------------------------------
$script:OwnLock = $false
$script:TempFiles = [System.Collections.Generic.List[string]]::new()
$script:SiteOffline = $false

# --- Git helpers -------------------------------------------------------------
function Get-GitCommit {
    try { return (git -C $repoRoot rev-parse --short HEAD 2>$null).Trim() }
    catch { return "unknown" }
}

# --- Deployment lock ---------------------------------------------------------
function Invoke-AcquireLock {
    Write-Step "Acquiring deployment lock..."

    $existing = Get-FtpFileContent $LOCK_REMOTE
    if ($existing) {
        try { $lk = $existing | ConvertFrom-Json } catch { $lk = $null }
        $age = if ($lk.started) {
            ([datetime]::Now - [datetime]::Parse($lk.started)).TotalMinutes
        }
        else { $LockTimeoutMinutes + 1 }
        $info = "machine='$($lk.machine)' user='$($lk.user)' commit='$($lk.commit)' started='$($lk.started)'"

        if ($age -gt $LockTimeoutMinutes) {
            if ($ForceUnlock) {
                Write-Warn "Stale lock ($([int]$age) min old) -- removing. $info"
                Invoke-FtpDelete $LOCK_REMOTE
            }
            else {
                Write-Err "Lock is stale ($([int]$age) min old) but -ForceUnlock not used. $info"
                exit 1
            }
        }
        elseif ($ForceUnlock) {
            Write-Warn "Lock is ACTIVE but -ForceUnlock used -- removing anyway. $info"
            Invoke-FtpDelete $LOCK_REMOTE
        }
        else {
            Write-Err "Deployment is currently running ($([int]$age) min old). $info"
            Write-Err "Use -ForceUnlock ONLY if you are sure it crashed."
            exit 1
        }
    }

    $lockData = @{
        machine = $env:COMPUTERNAME
        user    = $env:USERNAME
        pid     = $PID
        commit  = Get-GitCommit
        started = [datetime]::Now.ToString("o")
    } | ConvertTo-Json -Compress

    if ($DryRun) { Write-Dry "Would create lock: $lockData"; return }

    Invoke-FtpUploadText -RemotePath $LOCK_REMOTE -Content $lockData
    # Race condition check
    Start-Sleep -Milliseconds 500
    $verify = Get-FtpFileContent $LOCK_REMOTE
    if ($verify -ne $lockData) {
        throw "Lock race condition -- another deployer acquired the lock simultaneously. Aborting."
    }
    $script:OwnLock = $true
    Write-Ok "Lock acquired. (machine=$($env:COMPUTERNAME), pid=$PID)"
}

function Invoke-ReleaseLock {
    if ($DryRun -or -not $script:OwnLock) { return }
    try {
        $current = Get-FtpFileContent $LOCK_REMOTE
        if ($current) {
            try { $lk = $current | ConvertFrom-Json } catch { $lk = $null }
            if ($lk.pid -eq $PID -and $lk.machine -eq $env:COMPUTERNAME) {
                Invoke-FtpDelete $LOCK_REMOTE
                $script:OwnLock = $false
                Write-Ok "Lock released."
            }
            else {
                Write-Warn "Lock ownership changed -- not deleting foreign lock."
            }
        }
    }
    catch { Write-Warn "Could not release lock: $($_.Exception.Message)" }
}

function Stop-Deploy ([string]$ErrorMsg) {
    Write-Err "Deployment aborted: $ErrorMsg"
    if ($script:TempFiles.Count -gt 0) {
        Write-Info "Cleaning up $($script:TempFiles.Count) temporary upload file(s)..."
        foreach ($tf in $script:TempFiles) { try { Invoke-FtpDelete $tf } catch { } }
    }
    if ($script:SiteOffline) {
        Write-Warn "Leaving site OFFLINE (app_offline.htm) due to error. Please fix and re-deploy."
    }
    Invoke-ReleaseLock
    exit 1
}

# --- Manifest helpers --------------------------------------------------------
function Get-ServerManifest {
    Write-Step "Downloading manifest from server..."
    $content = Get-FtpFileContent $MANIFEST_REMOTE
    if (-not $content) {
        Write-Warn "No manifest found on server. Full upload will be performed."
        return @{}
    }
    try {
        $json = $content | ConvertFrom-Json -AsHashtable
        if ($json.files) { return $json.files }
        return $json
    }
    catch {
        Write-Warn "Server manifest corrupted. Full upload will be performed."
        return @{}
    }
}

function Set-ServerManifest ([hashtable]$Files) {
    if ($DryRun) { Write-Dry "Would update server manifest with $($Files.Count) entries."; return }
    Write-Step "Updating manifest on server..."
    $data = @{
        updated = [datetime]::Now.ToString("o")
        machine = $env:COMPUTERNAME
        commit  = Get-GitCommit
        files   = $Files
    } | ConvertTo-Json -Depth 5 -Compress
    Invoke-FtpUploadText -RemotePath $MANIFEST_REMOTE -Content $data
    Write-Ok "Manifest updated."
}

function Get-LocalHashes ([string]$DirPath) {
    $dict = @{}
    $files = Get-ChildItem -Path $DirPath -File -Recurse
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($DirPath.Length).TrimStart('\').Replace('\', '/')
        if (Test-ProtectedPath $rel) { continue }
        $hash = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
        $dict[$rel] = $hash
    }
    return $dict
}

# --- app_offline.htm content -------------------------------------------------
$APP_OFFLINE_HTML = @'
<!DOCTYPE html>
<html lang="en-US">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>ATS - System Update</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:'Segoe UI',Roboto,sans-serif;background:#0b0f19;color:#fff;
         display:flex;align-items:center;justify-content:center;min-height:100vh;text-align:center}
    .card{background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);
          border-radius:24px;padding:3rem;max-width:440px;backdrop-filter:blur(20px)}
    h1{font-size:1.7rem;font-weight:800;margin-bottom:1rem}
    .accent{color:#6366f1}
    p{opacity:.7;line-height:1.7}
  </style>
</head>
<body>
  <div class="card">
    <h1><span class="accent">ATS</span> System Update</h1>
    <p>We are currently upgrading the system.<br>Please wait a moment - approximately 3-5 minutes.</p>
  </div>
</body>
</html>
'@

# =============================================================================
# ENTRY POINT - validate then run
# =============================================================================

# Credentials validation
if (-not $Server) { Write-Err "FTP server not set. Use -Server or set FTP_SERVER env var."; exit 1 }
if (-not $Username) { Write-Err "FTP username not set. Use -Username or set FTP_USER env var."; exit 1 }
if (-not $Password) { Write-Err "FTP password not set. Use -Password or set FTP_PASS env var."; exit 1 }

if ($DryRun) {
    Write-Log INFO "================================================================" Cyan
    Write-Log INFO "  DRY RUN - no changes will be made" Cyan
    Write-Log INFO "================================================================" Cyan
}

Write-Info "Server  : $Server  ($(if($UseTls){'FTPS'}else{'FTP'}))"
Write-Info "Remote  : $RemotePath"
Write-Info "Machine : $($env:COMPUTERNAME)  |  User: $($env:USERNAME)  |  PID: $PID"
Write-Info "Commit  : $(Get-GitCommit)"

Initialize-FtpConnection -Server $Server -Username $Username -Password $Password -UseTls:$UseTls

# -----------------------------------------------------------------------------
# PHASE 1: BUILD
# -----------------------------------------------------------------------------
if (-not $SkipBuild) {
    # Clean slate
    if (Test-Path "$repoRoot\deploy") { Remove-Item "$repoRoot\deploy"          -Recurse -Force }
    if (Test-Path "$repoRoot\backend\wwwroot") { Remove-Item "$repoRoot\backend\wwwroot" -Recurse -Force }
    New-Item "$repoRoot\deploy"          -ItemType Directory | Out-Null
    New-Item "$repoRoot\backend\wwwroot" -ItemType Directory | Out-Null

    Write-Step "1. Building Frontend (npm run build)..."
    Set-Location $repoRoot
    npm run build
    if ($LASTEXITCODE -ne 0) { Write-Err "Frontend build failed (exit $LASTEXITCODE)"; exit 1 }
    Write-Ok "Frontend built."

    Write-Info "Copying dist\ -> backend\wwwroot..."
    Copy-Item "$repoRoot\dist\*" "$repoRoot\backend\wwwroot" -Recurse -Force

    Write-Step "2. Publishing Backend (dotnet publish, win-x86)..."
    Set-Location "$repoRoot\backend"
    dotnet publish -c Release -r win-x86 --self-contained true -o $BACKEND_LOCAL
    if ($LASTEXITCODE -ne 0) { Write-Err "Backend publish failed (exit $LASTEXITCODE)"; exit 1 }
    Write-Ok "Backend published."
    Set-Location $repoRoot
}
else {
    Write-Warn "SkipBuild specified -- using existing artifacts in deploy\backend\."
}

if (-not (Test-Path $BACKEND_LOCAL)) {
    Write-Err "deploy\backend not found. Run without -SkipBuild first."
    exit 1
}

# -----------------------------------------------------------------------------
# PHASE 2: FTP DEPLOY
# -----------------------------------------------------------------------------
try {

    # --- 2a. Lock ------------------------------------------------------------
    Invoke-AcquireLock

    # --- 2b. Server manifest -------------------------------------------------
    $serverHashes = Get-ServerManifest     # [string->string] relPath -> SHA256

    # --- 2c. Local hashes ----------------------------------------------------
    Write-Step "Scanning and hashing local files..."
    $localHashes = Get-LocalHashes $BACKEND_LOCAL
    Write-Ok "Found $($localHashes.Count) local file(s)."

    # --- 2d. Diff ------------------------------------------------------------
    $toUpload = [System.Collections.Generic.List[string]]::new()
    $toDelete = [System.Collections.Generic.List[string]]::new()
    $unchanged = 0

    foreach ($kv in $localHashes.GetEnumerator()) {
        if ($serverHashes.ContainsKey($kv.Key) -and $serverHashes[$kv.Key] -eq $kv.Value) {
            $unchanged++
        }
        else {
            [void]$toUpload.Add($kv.Key)
        }
    }

    foreach ($path in @($serverHashes.Keys)) {
        if ($localHashes.ContainsKey($path)) { continue }
        if (Test-ProtectedPath $path) {
            Write-Info "Protected -- skip delete: $path"
            continue
        }
        [void]$toDelete.Add($path)
    }

    Write-Info "Diff: $($toUpload.Count) to upload | $($toDelete.Count) to delete | $unchanged unchanged"

    if ($toUpload.Count -eq 0 -and $toDelete.Count -eq 0) {
        Write-Ok "Server is already up to date -- nothing to do."
        Invoke-ReleaseLock
        exit 0
    }

    # --- 2e. Take site offline -----------------------------------------------
    Write-Step "Putting site offline (app_offline.htm)..."
    if ($DryRun) {
        Write-Dry "Would upload app_offline.htm"
    }
    else {
        Invoke-FtpUploadText -RemotePath $OFFLINE_REMOTE -Content $APP_OFFLINE_HTML
        $script:SiteOffline = $true
        Write-Ok "Site offline."
        Write-Info "Waiting 10 s for app pool to release file handles..."
        Start-Sleep -Seconds 10
    }

    # --- 2f. Upload changed / new files --------------------------------------
    Write-Step "Uploading $($toUpload.Count) changed/new file(s)..."
    $done = 0
    foreach ($rel in $toUpload) {
        if (Test-ProtectedPath $rel) {
            Write-Warn "Protected -- skipping upload: $rel"
            continue
        }
        $localFile = [System.IO.Path]::Combine($BACKEND_LOCAL, $rel.Replace('/', '\'))
        $remoteFull = ("$RemotePath/$rel" -replace '\\', '/') -replace '//', '/'
        $remoteTmp = "$remoteFull.uploading"

        if (-not (Test-Path -LiteralPath $localFile)) {
            Write-Warn "Local file missing -- skipping: $rel"
            continue
        }

        if ($DryRun) { Write-Dry "Would upload: $rel"; $done++; continue }

        # Track temp file so we can clean it on error
        [void]$script:TempFiles.Add($remoteTmp)

        Invoke-FtpUploadFile -LocalPath $localFile -RemotePath $remoteTmp
        Invoke-FtpDelete $remoteFull
        try {
            Invoke-FtpRename -OldPath $remoteTmp -NewName ([System.IO.Path]::GetFileName($remoteFull))
            [void]$script:TempFiles.Remove($remoteTmp)
        }
        catch {
            Write-Warn "Rename failed for '$rel' -- falling back to direct upload: $($_.Exception.Message)"
            try { Invoke-FtpDelete $remoteTmp } catch { }
            [void]$script:TempFiles.Remove($remoteTmp)
            Invoke-FtpUploadFile -LocalPath $localFile -RemotePath $remoteFull
        }

        $done++
        Write-Info "  [$done/$($toUpload.Count)] $rel"
    }
    Write-Ok "Uploaded $done file(s)."

    # --- 2g. Delete removed files --------------------------------------------
    if ($toDelete.Count -gt 0) {
        Write-Step "Deleting $($toDelete.Count) removed file(s)..."
        foreach ($rel in $toDelete) {
            $remoteFull = ("$RemotePath/$rel" -replace '\\', '/') -replace '//', '/'
            if ($DryRun) { Write-Dry "Would delete: $rel"; continue }
            Invoke-FtpDelete $remoteFull
            Write-Info "  Deleted: $rel"
        }
        Write-Ok "Deleted $($toDelete.Count) file(s)."
    }

    # --- 2h. Update manifest (LAST successful step) --------------------------
    $newManifest = @{}
    foreach ($kv in $localHashes.GetEnumerator()) { $newManifest[$kv.Key] = $kv.Value }
    Set-ServerManifest -Files $newManifest

    # --- 2i. Bring site back online ------------------------------------------
    Write-Step "Bringing site back online..."
    if ($DryRun) {
        Write-Dry "Would remove app_offline.htm"
    }
    else {
        Invoke-FtpDelete $OFFLINE_REMOTE
        $script:SiteOffline = $false
        Write-Ok "Site is LIVE."
    }

    # --- 2j. Release lock ----------------------------------------------------
    Invoke-ReleaseLock

    Write-Log OK "================================================================" Green
    Write-Log OK "  Deployment complete!" Green
    Write-Log OK "  Uploaded: $done  |  Deleted: $($toDelete.Count)  |  Unchanged: $unchanged" Green
    Write-Log OK "================================================================" Green

}
catch {
    Stop-Deploy $_.Exception.Message
}
