$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('shortcut-fullscreen-test-' + [guid]::NewGuid().ToString('N'))
$installer = Join-Path $repo 'Waterfox_SM\Set_Fullscreen_UI.ps1'
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'chrome') -Force | Out-Null
    $cssPath = Join-Path $fixture 'chrome\userChrome.css'
    $userPath = Join-Path $fixture 'user.js'
    $originalCss = '@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");' + [Environment]::NewLine + '#unrelated { color: red; }' + [Environment]::NewLine
    $originalPrefs = 'user_pref("unrelated.setting", 42);' + [Environment]::NewLine
    [IO.File]::WriteAllText($cssPath, $originalCss)
    [IO.File]::WriteAllText($userPath, $originalPrefs)
    & $installer -ProfileDir $fixture
    $cssHash = (Get-FileHash -LiteralPath $cssPath).Hash
    $userHash = (Get-FileHash -LiteralPath $userPath).Hash
    & $installer -ProfileDir $fixture
    if ((Get-FileHash -LiteralPath $cssPath).Hash -ne $cssHash -or (Get-FileHash -LiteralPath $userPath).Hash -ne $userHash) {
        throw 'Repeated installation changed content'
    }
    $css = [IO.File]::ReadAllText($cssPath)
    if (-not $css.Contains('*|div#fullscr-toggler') -or -not $css.Contains('display: none !important')) {
        throw 'Fullscreen hover rule missing'
    }
    if ([IO.File]::ReadAllText("$cssPath.shortcut-ui.bak") -cne $originalCss) { throw 'CSS backup changed' }
    if ([IO.File]::ReadAllText("$userPath.shortcut-ui.bak") -cne $originalPrefs) { throw 'Prefs backup changed' }
    & $installer -ProfileDir $fixture -Remove
    if ([IO.File]::ReadAllText($cssPath) -cne $originalCss) { throw 'Original CSS was not preserved' }
    if ([IO.File]::ReadAllText($userPath) -cne $originalPrefs) { throw 'Original prefs were not preserved' }
    Write-Output 'PASS fullscreen rule, idempotent install, original backups and scoped removal'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'shortcut-fullscreen-test-*') {
        throw 'Unsafe test cleanup path'
    }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
