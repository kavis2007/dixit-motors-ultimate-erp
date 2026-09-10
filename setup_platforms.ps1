$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
Write-Host 'Dixit Motors Management App - final platform setup' -ForegroundColor Cyan
flutter create --platforms=android,windows .
flutter pub get
dart run flutter_launcher_icons
if (Test-Path .\test\widget_test.dart) { Remove-Item .\test\widget_test.dart -Force }
$manifest = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
  $text = Get-Content $manifest -Raw
  if ($text -notmatch 'android.permission.CAMERA') {
    $text = $text -replace '<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">`r`n    <uses-permission android:name="android.permission.CAMERA" />`r`n    <uses-permission android:name="android.permission.INTERNET" />'
    Set-Content -Path $manifest -Value $text -Encoding UTF8
  }
}
flutter analyze
Write-Host 'Platforms, launcher icons, camera/internet permissions and analyzer check completed.' -ForegroundColor Green
