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
    # A clean AOT build avoids stale Gradle/Flutter depfiles on Windows paths with spaces.
    # Keep previously delivered versioned APKs before Flutter removes generated build output.
    $savedApks = Join-Path $mobileRoot 'releases/previous-apks'
    $outputDirectory = Join-Path $mobileRoot 'build/app/outputs/flutter-apk'
    if (Test-Path -LiteralPath $outputDirectory) {
        New-Item -ItemType Directory -Path $savedApks -Force | Out-Null
        Get-ChildItem -LiteralPath $outputDirectory -Filter 'DrapeMind-*.apk' -File | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $savedApks $_.Name) -Force
        }
    }
    & $FlutterExecutable clean
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo limpiar la compilación anterior.' }
    & $FlutterExecutable build apk --release "--dart-define=DRAPEMIND_API_URL=$ApiUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter no pudo completar la APK.' }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $outputDirectory 'app-release.apk'))
    try {
        $entry = $archive.GetEntry('lib/arm64-v8a/libapp.so')
        if ($null -eq $entry) { throw 'La APK no contiene el binario ARM64 de la aplicación.' }
        $stream = $entry.Open()
        $memory = [IO.MemoryStream]::new()
        try {
            $stream.CopyTo($memory)
            $compiled = [Text.Encoding]::UTF8.GetString($memory.ToArray())
            foreach ($marker in @('/offline/operations', '/offline/operations/results', '/retail/reservations', $ApiUrl)) {
                if (-not $compiled.Contains($marker)) { throw "La APK no contiene el código esperado: $marker" }
            }
        }
        finally { $stream.Dispose(); $memory.Dispose() }
    }
    finally { $archive.Dispose() }

    $versionMatch = [regex]::Match((Get-Content -LiteralPath 'pubspec.yaml' -Raw), '(?m)^version:\s*(\S+)')
    if (-not $versionMatch.Success) { throw 'Falta la versión en pubspec.yaml.' }
    $version = $versionMatch.Groups[1].Value
    $outputDirectory = Join-Path $mobileRoot 'build/app/outputs/flutter-apk'
    $apkPath = Join-Path $outputDirectory "DrapeMind-$version.apk"
    Copy-Item -LiteralPath (Join-Path $outputDirectory 'app-release.apk') -Destination $apkPath -Force
    if (Test-Path -LiteralPath $savedApks) {
        Get-ChildItem -LiteralPath $savedApks -Filter 'DrapeMind-*.apk' -File | Where-Object { $_.Name -ne [IO.Path]::GetFileName($apkPath) } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $outputDirectory $_.Name) -Force
        }
    }
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
