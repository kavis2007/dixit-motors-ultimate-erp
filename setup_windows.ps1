$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path '.\windows')) { flutter create --platforms=windows . }
flutter pub get
flutter analyze
flutter build windows --release
Write-Host 'Windows release ready: build\windows\x64\runner\Release\dixit_motors_management_app.exe' -ForegroundColor Green
