param(
  [ValidateSet('doctor', 'devices', 'test', 'analyze', 'web', 'apk', 'run', 'server', 'itch')]
  [string]$Task = 'doctor',
  [string]$Device,
  [string]$ServerUrl
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
$defines = @()
if ($ServerUrl) {
  $uri = $null
  if (![Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.Fragment -or $uri.UserInfo) {
    throw 'ServerUrl must be an HTTPS server address, without a path, query, or credentials.'
  }
  $defines = @("--dart-define=ROOM_SERVER=$($ServerUrl.TrimEnd('/'))")
}
Push-Location $PSScriptRoot
try {
  switch ($Task) {
    'itch' {
      if (-not $ServerUrl) {
        $defines = @('--dart-define=ROOM_SERVER=https://pocket-party-rooms.onrender.com')
      }
      & python tool/prepare_signing.py
      if ($LASTEXITCODE -ne 0) { throw 'Signing setup failed' }
      & $flutter build web --release --no-web-resources-cdn @defines
      if ($LASTEXITCODE -ne 0) { throw 'Web build failed' }
      & $flutter build apk --release @defines
      if ($LASTEXITCODE -ne 0) { throw 'Android release build failed' }
      & python tool/package_itch.py
    }
    'server' { & (Join-Path $workspace '.tools\flutter\bin\dart.bat') server/main.dart }
    'web' { & $flutter run -d chrome @defines }
    'apk' { & $flutter build apk --debug @defines }
    'run' {
      if ($Device) { & $flutter run -d $Device @defines } else { & $flutter run @defines }
    }
    default { & $flutter $Task }
  }
  if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE" }
} finally {
  Pop-Location
}
