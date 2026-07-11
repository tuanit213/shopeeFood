$ErrorActionPreference = 'Stop'

$emulator = Join-Path $env:LOCALAPPDATA 'Android\Sdk\emulator\emulator.exe'
& $emulator -avd 'Medium_Phone_API_36.1' -gpu host -no-snapshot-load -no-boot-anim
