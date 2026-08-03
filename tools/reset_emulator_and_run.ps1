# Don dung luong emulator roi chay app kem API key - lam het trong 1 lenh.
#
# Cach dung (PowerShell):
#   & 'D:\ProjectCaNhan\ShopeeFood\shopeefood\tools\reset_emulator_and_run.ps1'
#
# Muon giu nguyen du lieu may ao (khong wipe):
#   & '...\reset_emulator_and_run.ps1' -SkipWipe
#
# LUU Y: file nay chi dung ky tu ASCII. Windows PowerShell 5.1 doc .ps1 theo
# ANSI, nen ky tu tieng Viet co dau se lam vo cu phap script.

param(
    [string]$AvdName = "Medium_Phone_API_36.1",
    [int]$DataPartitionMB = 6144,
    [switch]$SkipWipe
)

$ErrorActionPreference = "Stop"

$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adb = Join-Path $sdk "platform-tools\adb.exe"
$emulator = Join-Path $sdk "emulator\emulator.exe"
$runAppScript = Join-Path $PSScriptRoot "run_app_with_maps_key.ps1"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

if (-not (Test-Path -LiteralPath $adb)) { throw "Khong tim thay adb: $adb" }
if (-not (Test-Path -LiteralPath $emulator)) { throw "Khong tim thay emulator: $emulator" }
if (-not (Test-Path -LiteralPath $runAppScript)) { throw "Khong tim thay: $runAppScript" }

# --- 1. Xem dung luong hien tai -------------------------------------------
Write-Step "Kiem tra dung luong /data"
& $adb devices
& $adb shell df -h /data

# --- 2. Tat emulator dang chay --------------------------------------------
Write-Step "Tat emulator dang chay (neu co)"
& $adb emu kill
Start-Sleep -Seconds 3

# --- 3. Tang dung luong o du lieu cua AVD ---------------------------------
if (-not $SkipWipe) {
    Write-Step "Dat dung luong /data = $DataPartitionMB MB"
    $configPath = Join-Path $env:USERPROFILE ".android\avd\$AvdName.avd\config.ini"

    if (Test-Path -LiteralPath $configPath) {
        $sizeValue = [string]$DataPartitionMB + "M"
        $newLine = "disk.dataPartition.size=" + $sizeValue
        $lines = @(Get-Content -LiteralPath $configPath)
        $found = $false
        $output = @()

        foreach ($line in $lines) {
            if ($line.StartsWith("disk.dataPartition.size=")) {
                $output += $newLine
                $found = $true
            }
            else {
                $output += $line
            }
        }
        if (-not $found) {
            $output += $newLine
        }

        Set-Content -LiteralPath $configPath -Value $output -Encoding ASCII
        Write-Host "Da cap nhat: $configPath" -ForegroundColor Green
    }
    else {
        Write-Warning "Khong thay $configPath - bo qua buoc tang dung luong."
    }
}

# --- 4. Khoi dong emulator ------------------------------------------------
Write-Step "Khoi dong emulator $AvdName"
$emulatorArgs = @("-avd", $AvdName)
if (-not $SkipWipe) {
    $emulatorArgs += "-wipe-data"
    Write-Host "Che do WIPE DATA: may ao bi xoa sach, ban can DANG NHAP LAI trong app." -ForegroundColor Yellow
}
Start-Process -FilePath $emulator -ArgumentList $emulatorArgs | Out-Null

# --- 5. Cho emulator boot xong -------------------------------------------
Write-Step "Cho emulator boot (toi da 5 phut)"
& $adb start-server | Out-Null
& $adb wait-for-device

$deadline = (Get-Date).AddMinutes(5)
$booted = $false
while ((Get-Date) -lt $deadline) {
    $state = (& $adb shell getprop sys.boot_completed | Out-String).Trim()
    if ($state -eq "1") {
        $booted = $true
        break
    }
    Write-Host "  ...dang boot" -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
}
if (-not $booted) {
    throw "Emulator boot qua lau. Mo emulator thu cong roi chay run_app_with_maps_key.ps1"
}
Write-Host "Emulator da san sang." -ForegroundColor Green

# --- 6. Don cache + bao dung luong trong ---------------------------------
Write-Step "Don cache va kiem tra dung luong trong"
& $adb shell pm trim-caches 2G
& $adb shell df -h /data

# --- 7. Chay app kem API key --------------------------------------------
Write-Step "Chay app demo (kem Geoapify / Google Maps key)"
Write-Host "App se doc du lieu demo va anh mon an tu assets." -ForegroundColor Yellow

& $runAppScript
