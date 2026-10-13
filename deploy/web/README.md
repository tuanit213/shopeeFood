# Flutter Web VPS deployment

This package serves the compiled Flutter Web frontend. The Firebase backend is deployed separately with Firebase CLI.

## Build locally

```powershell
& 'C:\Users\LOQ\development\flutter\bin\flutter.bat' pub get
& 'C:\Users\LOQ\development\flutter\bin\flutter.bat' build web --release
docker compose -f deploy/web/compose.yaml build
docker compose -f deploy/web/compose.yaml up -d
```

Verify:

```powershell
curl.exe http://127.0.0.1:8080/healthz
curl.exe -I http://127.0.0.1:8080/
```

## Deploy on VPS

Prerequisites: Docker Engine, Docker Compose plugin, a DNS record pointing to the VPS, and firewall rules allowing HTTP/HTTPS.

```bash
git clone https://github.com/tuanit213/shopeeFood.git
cd shopeeFood
git switch <reviewed-branch>
flutter pub get
flutter build web --release
docker compose -f deploy/web/compose.yaml up -d --build
curl http://127.0.0.1:8080/healthz
```

Put the container behind the VPS HTTPS reverse proxy, or change the published port to match the server policy.

## Rollback

```bash
git switch --detach <previous-good-commit>
flutter build web --release
docker compose -f deploy/web/compose.yaml up -d --build
curl http://127.0.0.1:8080/healthz
```

Do not deploy Firebase service-account JSON files to the static frontend container.

## Passwordless redeploy from Windows

Install the deployment public key in `/root/.ssh/authorized_keys`, then run:

```powershell
Set-Location D:\ProjectCaNhan\shoppeFood
.\deploy\web\redeploy-vps.ps1
```

The script uses environment variables when a different server is required:

```powershell
$env:VPS_HOST='157.66.100.124'
$env:VPS_USER='root'
$env:DEPLOY_PATH='/var/www/shoppefood'
$env:VPS_IDENTITY_FILE="$env:USERPROFILE\.ssh\shoppefood_vps_ed25519"
.\deploy\web\redeploy-vps.ps1
```

No password, private key, Firebase secret, or service-account file is stored in the repository.
