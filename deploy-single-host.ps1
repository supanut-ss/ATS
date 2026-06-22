param(
    [string]$Server = "94.237.76.153",
    [string]$Username = "thaipes",
    [string]$Password = "Ws7#3es2",
    [string]$RemotePath = "ats.thaipesleague.com" 
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

# 0. Preparation
if (Test-Path "$repoRoot\deploy") { Remove-Item -Path "$repoRoot\deploy" -Recurse -Force }
New-Item -Path "$repoRoot\deploy" -ItemType Directory

if (Test-Path "$repoRoot\backend\wwwroot") { Remove-Item -Path "$repoRoot\backend\wwwroot" -Recurse -Force }
New-Item -Path "$repoRoot\backend\wwwroot" -ItemType Directory

# 1. Build Frontend
Write-Host "1. Building Frontend..." -ForegroundColor Yellow
Set-Location "$repoRoot"
npm run build
if ($LASTEXITCODE -ne 0) { throw "Frontend build failed" }

# Copy built frontend assets to wwwroot of backend
Write-Host "Copying built frontend into backend/wwwroot..." -ForegroundColor Yellow
Copy-Item -Path "$repoRoot\dist\*" -Destination "$repoRoot\backend\wwwroot" -Recurse -Force

# 2. Publish Backend (win-x86 for hosting compatibility)
Write-Host "2. Publishing Backend (win-x86)..." -ForegroundColor Yellow
Set-Location "$repoRoot\backend"
dotnet publish -c Release -r win-x86 --self-contained true -o "$repoRoot\deploy\backend"
if ($LASTEXITCODE -ne 0) { throw "Backend publish failed" }

# 3. Create maintenance page
Write-Host "3. Creating maintenance page..." -ForegroundColor Yellow
$appOfflineContent = @"
<!DOCTYPE html>
<html lang="th-TH">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ATS Webhook Maintenance</title>
    <style>
        body { font-family: 'Segoe UI', Roboto, sans-serif; background: #0b0f19; color: white; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
        .card { background: rgba(255,255,255,0.03); padding: 3rem; border-radius: 32px; border: 1px solid rgba(255,255,255,0.08); backdrop-filter: blur(20px); max-width: 450px; }
        h1 { margin: 0; font-size: 1.75rem; font-weight: 800; color: #f3f4f6; }
        p { opacity: 0.7; margin-top: 1rem; font-size: 1rem; line-height: 1.6; }
        .accent { color: #6366f1; font-weight: 800; }
    </style>
</head>
<body>
    <div class="card">
        <h1><span class="accent">ATS</span> กำลังอัปเดตระบบ</h1>
        <p>เรากำลังอัปเกรดระบบตัวคัดกรองสัญญาณและประสิทธิภาพแดชบอร์ด<br>กรุณารอสักครู่ (ประมาณ 3-5 นาที)</p>
    </div>
</body>
</html>
"@
$tempAppOfflinePath = "$repoRoot\deploy\app_offline.htm"
Set-Content -Path $tempAppOfflinePath -Value $appOfflineContent -Force

# 4. Uploading...
$pwsh = if (Get-Command powershell -ErrorAction SilentlyContinue) { "powershell" } else { "pwsh" }

Write-Host "4. Taking app offline (Uploading app_offline.htm)..." -ForegroundColor Yellow
& $pwsh -ExecutionPolicy Bypass -File "$repoRoot\upload-ftp.ps1" `
    -Server $Server -Username $Username -Password $Password `
    -LocalPath "$repoRoot\deploy" -RemotePath $RemotePath -ExcludePaths @("backend")

Write-Host "App is offline. Waiting 15 seconds for app pool to release files..."
Start-Sleep -Seconds 15

Write-Host "5. Uploading application files (Integrated Frontend + Backend)..." -ForegroundColor Yellow
& $pwsh -ExecutionPolicy Bypass -File "$repoRoot\upload-ftp.ps1" `
    -Server $Server -Username $Username -Password $Password `
    -LocalPath "$repoRoot\deploy\backend" -RemotePath $RemotePath

# 6. Bring App Online
Write-Host "6. Bringing app back online..." -ForegroundColor Yellow
$delReq = [System.Net.FtpWebRequest]::Create("ftp://$Server/$RemotePath/app_offline.htm")
$delReq.Method = [System.Net.WebRequestMethods+Ftp]::DeleteFile
$delReq.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
$delReq.UsePassive = $true
try {
    $delResp = $delReq.GetResponse()
    $delResp.Close()
    Write-Host "app_offline.htm removed. Website is live!" -ForegroundColor Green
} catch {
    Write-Warning "Could not remove app_offline.htm automatically. Please delete it via FTP."
}

Remove-Item $tempAppOfflinePath -Force -ErrorAction SilentlyContinue
Set-Location $repoRoot
Write-Host "--- Deployment Complete! ---" -ForegroundColor Cyan
