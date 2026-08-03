$ErrorActionPreference = 'Stop'

$projectPath = Join-Path $PSScriptRoot 'backend\ATS.Backend.csproj'
$configPath = Join-Path $PSScriptRoot 'backend\appsettings.Demo.json'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Missing backend\appsettings.Demo.json. Copy appsettings.Demo.example.json and configure a separate Demo database first.'
}

dotnet run --project $projectPath --launch-profile demo
