param(
  [ValidateSet('doctor', 'devices', 'test', 'analyze', 'web', 'apk', 'run', 'server')]
  [string]$Task = 'doctor',
  [string]$Device
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$env:PUB_CACHE = Join-Path $workspace '.tools\pub-cache'
$env:GRADLE_USER_HOME = Join-Path $workspace '.tools\gradle-cache'
$env:ANDROID_HOME = Join-Path $workspace '.tools\android-sdk'
$env:ANDROID_USER_HOME = Join-Path $workspace '.tools\android-user'
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.2.10-hotspot'
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"
$flutter = Join-Path $workspace '.tools\flutter\bin\flutter.bat'
Push-Location $PSScriptRoot
try {
  switch ($Task) {
    'server' { & (Join-Path $workspace '.tools\flutter\bin\dart.bat') server/main.dart }
    'web' { & $flutter run -d chrome }
    'apk' { & $flutter build apk --debug }
    'run' {
      if ($Device) { & $flutter run -d $Device } else { & $flutter run }
    }
    default { & $flutter $Task }
  }
  if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE" }
} finally {
  Pop-Location
}
