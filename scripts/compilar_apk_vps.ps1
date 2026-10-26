param(
    [string]$FlutterExecutable = 'flutter',
    [string]$ApiUrl = 'https://167.86.106.105/DrapeMind'
)

$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$apiUri = [Uri]$ApiUrl
if (-not $apiUri.IsAbsoluteUri -or $apiUri.Scheme -ne 'https' -or $apiUri.Query -or $apiUri.Fragment) {
    throw 'La compilación de distribución requiere una URL HTTPS absoluta, sin parámetros.'
}
$ApiUrl = $ApiUrl.TrimEnd('/')
if ($ApiUrl.EndsWith('/api/v1')) {
    throw 'Usa la URL base (por ejemplo https://167.86.106.105/DrapeMind), sin /api/v1.'
}

Push-Location -LiteralPath $mobileRoot
try {
    Write-Host "Compilando DrapeMind para $ApiUrl" -ForegroundColor Cyan
    & $FlutterExecutable build apk --release "--dart-define=DRAPEMIND_API_URL=$ApiUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter no pudo completar la APK.' }

    $versionMatch = [regex]::Match((Get-Content -LiteralPath 'pubspec.yaml' -Raw), '(?m)^version:\s*(\S+)')
    if (-not $versionMatch.Success) { throw 'Falta la versión en pubspec.yaml.' }
    $version = $versionMatch.Groups[1].Value
    $outputDirectory = Join-Path $mobileRoot 'build/app/outputs/flutter-apk'
    $apkPath = Join-Path $outputDirectory "DrapeMind-$version.apk"
    Copy-Item -LiteralPath (Join-Path $outputDirectory 'app-release.apk') -Destination $apkPath -Force
    $hash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest = [ordered]@{
        version = $version
        api_base_url = $ApiUrl
        api_v1_url = "$ApiUrl/api/v1"
        apk = [IO.Path]::GetFileName($apkPath)
        sha256 = $hash
        built_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'release-vps.json') -Encoding UTF8
    Write-Host "APK lista: $apkPath" -ForegroundColor Green
    Write-Host "SHA256: $hash"
}
finally { Pop-Location }
