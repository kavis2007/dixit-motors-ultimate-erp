$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
flutter pub get
dart run flutter_launcher_icons
flutter clean
flutter build apk --release
Write-Host ''
Write-Host 'Dixit Motors Android release APK build completed.' -ForegroundColor Green
Write-Host 'APK: build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor Cyan
