param([string]$DeviceId = 'emulator-5554')
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectDirectory
try {
    & flutter run -d $DeviceId '--dart-define=SKP_MIDDLEWARE_BASE_URL=https://shri-middleware.ekarigar.com'
    if ($LASTEXITCODE -ne 0) { throw 'Live middleware app launch failed.' }
} finally {
    Pop-Location
}
