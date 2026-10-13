param(
    [string]$VpsHost = $(if ($env:VPS_HOST) { $env:VPS_HOST } else { '157.66.100.124' }),
    [string]$VpsUser = $(if ($env:VPS_USER) { $env:VPS_USER } else { 'root' }),
    [string]$DeployPath = $(if ($env:DEPLOY_PATH) { $env:DEPLOY_PATH } else { '/var/www/shoppefood' }),
    [string]$IdentityFile = $(if ($env:VPS_IDENTITY_FILE) { $env:VPS_IDENTITY_FILE } else { "$env:USERPROFILE\.ssh\shoppefood_vps_rsa" }),
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$flutter = 'C:\Users\LOQ\development\flutter\bin\flutter.bat'
$webBuild = Join-Path $projectRoot 'build\web'
$archive = Join-Path $env:TEMP 'shoppefood-web.tar.gz'
$remoteArchive = '/tmp/shoppefood-web.tar.gz'
$target = "$VpsUser@$VpsHost"
$sshArgs = @('-i', $IdentityFile, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new')

if (-not (Test-Path $IdentityFile)) {
    throw "SSH identity file not found: $IdentityFile"
}

if (-not $SkipBuild) {
    & $flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

    & $flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }

    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }

    & $flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }
}

if (-not (Test-Path (Join-Path $webBuild 'index.html'))) {
    throw "Flutter Web build is missing: $webBuild"
}

if (Test-Path $archive) {
    Remove-Item -LiteralPath $archive -Force
}

tar -C $webBuild -czf $archive .
if ($LASTEXITCODE -ne 0) { throw 'Creating web archive failed' }

& scp @sshArgs $archive "${target}:$remoteArchive"
if ($LASTEXITCODE -ne 0) { throw 'Uploading web archive failed' }

$deployCommand = @"
set -e
install -d -o www-data -g www-data '$DeployPath'
find '$DeployPath' -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
tar -xzf '$remoteArchive' -C '$DeployPath'
chown -R www-data:www-data '$DeployPath'
rm -f '$remoteArchive'
nginx -t
systemctl reload nginx
curl -fsS http://127.0.0.1/healthz
"@

& ssh @sshArgs $target $deployCommand
if ($LASTEXITCODE -ne 0) { throw 'Remote deployment or smoke test failed' }

$publicStatus = curl.exe -sS -o NUL -w '%{http_code}' "http://$VpsHost/"
if ($publicStatus -ne '200') {
    throw "Public smoke test failed with HTTP $publicStatus"
}

Write-Host "Deployment passed: http://$VpsHost/ (HTTP $publicStatus)"
