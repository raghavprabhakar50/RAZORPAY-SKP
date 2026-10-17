param([string]$DeviceId = 'emulator-5554')
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectDirectory
try {
    & flutter run -d $DeviceId '--dart-define=SKP_MIDDLEWARE_BASE_URL=http://10.0.2.2/Sri%20Krishna%20Pearls%20Middleware'
    if ($LASTEXITCODE -ne 0) { throw 'Local emulator launch failed.' }
} finally {
    Pop-Location
}
