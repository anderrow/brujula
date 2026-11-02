param([string]$Stage = 'inspect')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$cli = $env:BRUJULA_PLAYWRIGHT_CLI
if (-not $cli) {
    $npmCache = (& npm.cmd config get cache).Trim()
    $cli = Get-ChildItem -LiteralPath (Join-Path $npmCache '_npx') -Directory |
        ForEach-Object { Join-Path $_.FullName 'node_modules/playwright/cli.js' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $cli) { throw 'Install @playwright/cli first or set BRUJULA_PLAYWRIGHT_CLI to playwright/cli.js' }
function Invoke-Ui([string[]]$UiArgs) {
    $result = & node $cli cli '-s=brujula' @UiArgs
    $result | Out-File -LiteralPath 'output/playwright/cli.log' -Append -Encoding UTF8
    Write-Output $result
    if ($LASTEXITCODE -ne 0) { throw 'Playwright command failed' }
}
New-Item -ItemType Directory -Path 'output/playwright' -Force | Out-Null
if ($Stage -eq 'open') {
    Invoke-Ui @('open','http://127.0.0.1:8765','--browser','chrome')
    Invoke-Ui @('resize','393','852')
    Invoke-Ui @('snapshot')
} elseif ($Stage -eq 'inspect') {
    Invoke-Ui @('resize','393','852')
    Invoke-Ui @('reload')
    $snapshot = Invoke-Ui @('snapshot')
    Write-Output $snapshot
    Invoke-Ui @('run-code', "async (page) => { await page.screenshot({path: 'output/playwright/wheel.png', fullPage: true}); }")
    $match = [regex]::Match(($snapshot -join "`n"), 'button "Salud, [^"]+" \[ref=([^\]]+)\]')
    if (-not $match.Success) { throw 'Health button missing from current snapshot' }
    Invoke-Ui @('click', $match.Groups[1].Value)
    Invoke-Ui @('snapshot')
} elseif ($Stage -eq 'flows') {
    $code = Get-Content -LiteralPath 'tools/ui-reminders.js' -Raw -Encoding UTF8
    Invoke-Ui @('run-code', $code)
    Invoke-Ui @('console','error')
    Invoke-Ui @('snapshot')
} elseif ($Stage -eq 'reminders') {
    $code = Get-Content -LiteralPath 'tools/ui-reminders.js' -Raw -Encoding UTF8
    Invoke-Ui @('run-code', $code)
    Invoke-Ui @('snapshot')
} elseif ($Stage -eq 'close') {
    Invoke-Ui @('close')
}
