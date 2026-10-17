$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $projectRoot 'assets/images/skp logo 1.png'))

function Write-Icon([string]$RelativePath, [int]$Size, [double]$Scale, [bool]$Transparent = $false) {
    $target = Join-Path $projectRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    $format = [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    if ($Transparent) { $format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb }
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, $format)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        if ($Transparent) { $graphics.Clear([System.Drawing.Color]::Transparent) }
        else { $graphics.Clear([System.Drawing.Color]::White) }
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $ratio = $Size * $Scale / [Math]::Max($source.Width, $source.Height)
        $width = [int][Math]::Round($source.Width * $ratio)
        $height = [int][Math]::Round($source.Height * $ratio)
        $graphics.DrawImage($source, [int](($Size - $width) / 2), [int](($Size - $height) / 2), $width, $height)
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($entry in $densities.GetEnumerator()) {
        Write-Icon "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher.png" $entry.Value 0.90
        # Adaptive launchers mask the outer area: keep the full logo inside the safe zone.
        Write-Icon "android/app/src/main/res/mipmap-$($entry.Key)/ic_launcher_foreground.png" ([int]($entry.Value * 2.25)) 0.62 $true
    }
    $catalog = Get-Content (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
    foreach ($entry in ($catalog.images | Sort-Object filename -Unique)) {
        $size = [int]([double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x')))
        Write-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" $size 0.90
    }
    Write-Output 'Generated Android legacy/adaptive and iOS app icons from skp logo 1.png.'
} finally {
    $source.Dispose()
}
