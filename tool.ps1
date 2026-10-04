param(
  [ValidateSet('doctor', 'devices', 'test', 'analyze', 'web', 'apk', 'run', 'server')]
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
