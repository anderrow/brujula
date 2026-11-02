param([switch]$SkipLint)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$env:JAVA_HOME = (Get-Content -LiteralPath '.toolchain/java-home.txt' -Raw).Trim()
$env:ANDROID_HOME = Join-Path $projectRoot '.toolchain/android-sdk'
$env:ANDROID_USER_HOME = Join-Path $projectRoot '.toolchain/android-user'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.toolchain/gradle-home'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$versionName = [regex]::Match((Get-Content 'app/build.gradle' -Raw), "versionName\s+'([^']+)'").Groups[1].Value
if (-not $versionName) { throw 'Cannot read app version' }
$apkName = "Brujula-$versionName.apk"
$apkPath = Join-Path 'release' $apkName
$keyPath = Join-Path $projectRoot '.toolchain/brujula-release.jks'
$passwordFile = Join-Path $projectRoot '.toolchain/signing-password.dpapi'
if (-not (Test-Path -LiteralPath $passwordFile)) {
    $random = [byte[]]::new(32)
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($random)
    $rng.Dispose()
    $secure = ConvertTo-SecureString ([Convert]::ToBase64String($random)) -AsPlainText -Force
    $secure | ConvertFrom-SecureString | Set-Content -LiteralPath $passwordFile
}
$secure = Get-Content -LiteralPath $passwordFile | ConvertTo-SecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $env:BRUJULA_STORE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
$env:BRUJULA_KEYSTORE = $keyPath
try {
    if (-not (Test-Path -LiteralPath $keyPath)) {
        & "$env:JAVA_HOME/bin/keytool.exe" -genkeypair -keystore $keyPath -storepass:env BRUJULA_STORE_PASSWORD -keypass:env BRUJULA_STORE_PASSWORD -alias brujula -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Brujula, OU=Mobile, O=Brujula, C=NL'
        if ($LASTEXITCODE -ne 0) { throw 'APK signing key generation failed' }
    }
    $tasks = @('assembleRelease', 'testReleaseUnitTest')
    if (-not $SkipLint) { $tasks += 'lintRelease' }
    & '.toolchain/gradle-8.11.1/bin/gradle.bat' @tasks --console=plain
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
    New-Item -ItemType Directory -Path 'release' -Force | Out-Null
    Copy-Item -LiteralPath 'app/build/outputs/apk/release/app-release.apk' -Destination $apkPath -Force
    & "$env:ANDROID_HOME/build-tools/35.0.0/apksigner.bat" verify --verbose --print-certs $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
    & "$env:ANDROID_HOME/build-tools/35.0.0/zipalign.exe" -c -v 4 $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed' }
    $hash = (Get-FileHash $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $projectRoot "$apkPath.sha256"), "$hash  $apkName`n")
} finally {
    Remove-Item Env:BRUJULA_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:BRUJULA_KEYSTORE -ErrorAction SilentlyContinue
}
