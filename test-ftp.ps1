. $PSScriptRoot\upload-ftp.ps1
Initialize-FtpConnection -Server "94.237.76.153" -Username "thaipes" -Password "Ws7#3es2"

Write-Host "Testing directory creation..."
Ensure-FtpDirectory "ats.thaipesleague.com/testdir123"
Write-Host "Directory creation passed."

Write-Host "Testing file upload..."
Invoke-FtpUploadText "ats.thaipesleague.com/testdir123/test.txt" "Hello World"
Write-Host "File upload passed."

Write-Host "Cleaning up..."
Invoke-FtpDelete "ats.thaipesleague.com/testdir123/test.txt"
