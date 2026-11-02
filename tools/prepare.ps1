$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$env:JAVA_HOME = (Get-Content -LiteralPath '.toolchain/java-home.txt' -Raw).Trim()
$env:ANDROID_HOME = Join-Path $projectRoot '.toolchain/android-sdk'
$env:ANDROID_USER_HOME = Join-Path $projectRoot '.toolchain/android-user'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.toolchain/gradle-home'
$env:TEMP = Join-Path $projectRoot '.toolchain/tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$sdkManager = Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin/sdkmanager.bat'
1..50 | ForEach-Object { 'y' } | & $sdkManager "--sdk_root=$env:ANDROID_HOME" --licenses
if ($LASTEXITCODE -ne 0) { throw 'SDK license setup failed' }
& $sdkManager "--sdk_root=$env:ANDROID_HOME" 'platforms;android-36' 'build-tools;35.0.0' 'platform-tools'
if ($LASTEXITCODE -ne 0) { throw 'SDK package installation failed' }
$sdkPath = $env:ANDROID_HOME.Replace('\', '/').Replace(':', '\:')
[IO.File]::WriteAllText((Join-Path $projectRoot 'local.properties'), "sdk.dir=$sdkPath`n", [Text.UTF8Encoding]::new($false))
& '.toolchain/gradle-8.11.1/bin/gradle.bat' wrapper --gradle-version 8.11.1 --distribution-type bin --gradle-distribution-sha256-sum f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6
if ($LASTEXITCODE -ne 0) { throw 'Gradle wrapper setup failed' }
