param([switch]$SkipLint, [string]$SigningDirectory, [string]$GradleCacheDirectory)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$env:JAVA_HOME = (Get-Content -LiteralPath '.toolchain/java-home.txt' -Raw -Encoding UTF8).Trim()
$env:ANDROID_HOME = Join-Path $projectRoot '.toolchain/android-sdk'
$env:ANDROID_USER_HOME = Join-Path $projectRoot '.toolchain/android-user'
Remove-Item Env:ANDROID_SDK_HOME -ErrorAction SilentlyContinue
if (-not $GradleCacheDirectory) { $GradleCacheDirectory = Join-Path $projectRoot '.toolchain/gradle-home' }
$env:GRADLE_USER_HOME = $GradleCacheDirectory
$env:TEMP = Join-Path $projectRoot '.toolchain/tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$versionName = [regex]::Match((Get-Content 'app/build.gradle' -Raw -Encoding UTF8), "versionName\s+'([^']+)'").Groups[1].Value
if (-not $versionName) { throw 'Cannot read app version' }
$apk = "release/Brujula-$versionName.apk"
$aab = "release/Brujula-$versionName.aab"
if (-not $SigningDirectory) { $SigningDirectory = Join-Path $projectRoot '.toolchain' }
$keyPath = Join-Path $SigningDirectory 'brujula-release.jks'
$passwordFile = Join-Path $SigningDirectory 'signing-password.dpapi'
# Preserve update identity: missing original signing material must never create a replacement key.
if (-not (Test-Path -LiteralPath $keyPath) -or -not (Test-Path -LiteralPath $passwordFile)) {
    throw 'Existing release signing material is required. Supply its directory with -SigningDirectory; no replacement key will be created.'
}
function Capture-Check([string]$Name, [string[]]$CommandArgs) {
    & python 'tools/verification.py' capture $Name -- @CommandArgs
    if ($LASTEXITCODE -ne 0) { throw "Verification check failed: $Name" }
}
& python 'tools/verification.py' begin
if ($LASTEXITCODE -ne 0) { throw 'Could not initialize verification' }
Capture-Check 'core' @('node', '--test', 'tests/core.test.cjs')
Capture-Check 'web-generated' @('node', 'tools/build-web-app.cjs', '--check')
Capture-Check 'privacy-generated' @('node', 'tools/generate-privacy.cjs', '--check')
Capture-Check 'packaging-tests' @('python', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'verification_test.py')
New-Item -ItemType Directory -Path '.toolchain/calendar-tests' -Force | Out-Null
Capture-Check 'calendar-compile' @("$env:JAVA_HOME/bin/javac.exe", '-d', '.toolchain/calendar-tests', 'app/src/main/java/app/brujula/life/ReminderSchedule.java', 'tests/ReminderScheduleTest.java')
Capture-Check 'calendar' @("$env:JAVA_HOME/bin/java.exe", '-cp', '.toolchain/calendar-tests', 'ReminderScheduleTest')
$secure = Get-Content -LiteralPath $passwordFile | ConvertTo-SecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $env:BRUJULA_STORE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
$env:BRUJULA_KEYSTORE = $keyPath
try {
    if ($SkipLint) {
        & '.toolchain/gradle-8.11.1/bin/gradle.bat' '--no-daemon' '--console=plain' 'assembleRelease' 'bundleRelease' 'testReleaseUnitTest'
        throw 'SkipLint does not qualify a release receipt. Run again without SkipLint before packaging.'
    }
    Capture-Check 'android-release' @('.toolchain/gradle-8.11.1/bin/gradle.bat', '--no-daemon', '--console=plain', 'assembleRelease', 'bundleRelease', 'testReleaseUnitTest', 'lintRelease')
    New-Item -ItemType Directory -Path 'release' -Force | Out-Null
    Copy-Item -LiteralPath 'app/build/outputs/apk/release/app-release.apk' -Destination $apk -Force
    Copy-Item -LiteralPath 'app/build/outputs/bundle/release/app-release.aab' -Destination $aab -Force
    Capture-Check 'apk-signature' @("$env:ANDROID_HOME/build-tools/35.0.0/apksigner.bat", 'verify', '--verbose', '--print-certs', $apk)
    Capture-Check 'aab-signature' @("$env:JAVA_HOME/bin/java.exe", 'tools/VerifyBundleSignature.java', $aab, '9ba64e260876d4c314f13c747486316bbf6078de623274b35a7151855ef94dbe')
    Capture-Check 'bundle-validation' @("$env:JAVA_HOME/bin/java.exe", '-jar', '.toolchain/bundletool-1.18.3.jar', 'validate', "--bundle=$aab")
    Capture-Check 'alignment' @("$env:ANDROID_HOME/build-tools/35.0.0/zipalign.exe", '-c', '-v', '4', $apk)
    foreach ($artifact in @($apk, $aab)) {
        $hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText((Join-Path $projectRoot "$artifact.sha256"), "$hash  $([IO.Path]::GetFileName($artifact))`n")
    }
    & python 'tools/verification.py' finish
    if ($LASTEXITCODE -ne 0) { throw 'Verification receipt could not be completed' }
} finally {
    Remove-Item Env:BRUJULA_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:BRUJULA_KEYSTORE -ErrorAction SilentlyContinue
}
