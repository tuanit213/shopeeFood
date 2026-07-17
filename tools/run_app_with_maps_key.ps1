$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$geoapifyKeyPath = Join-Path $repoRoot "secrets\geoapify_api_key.txt"
$googleKeyPath = Join-Path $repoRoot "secrets\google_maps_api_key.txt"
$flutter = "C:\Users\LOQ\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat"
$device = if ($env:FLUTTER_DEVICE_ID) { $env:FLUTTER_DEVICE_ID } else { "emulator-5554" }

$dartDefines = @()

if (Test-Path -LiteralPath $geoapifyKeyPath) {
    $geoapifyKey = (Get-Content -LiteralPath $geoapifyKeyPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($geoapifyKey)) {
        $dartDefines += "--dart-define=GEOAPIFY_API_KEY=$geoapifyKey"
    }
}

if (Test-Path -LiteralPath $googleKeyPath) {
    $googleKey = (Get-Content -LiteralPath $googleKeyPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($googleKey)) {
        $dartDefines += "--dart-define=GOOGLE_MAPS_API_KEY=$googleKey"
    }
}

if ($dartDefines.Count -eq 0) {
    throw "Missing API key file. Add one of: $geoapifyKeyPath or $googleKeyPath"
}

& $flutter run -d $device @dartDefines
