# Requires no running browser automation; applies on the next Waterfox startup.
param(
    [Parameter(Mandatory=$true)][string]$ProfileDir,
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'
$profilePath = [IO.Path]::GetFullPath($ProfileDir)
if (-not (Test-Path -LiteralPath $profilePath -PathType Container)) {
    throw "Profil dizini yok: $profilePath"
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
$cssSource = Join-Path $PSScriptRoot 'fullscreen-ui.css'
if (-not $Remove -and -not (Test-Path -LiteralPath $cssSource)) {
    throw "CSS kaynagi yok: $cssSource"
}
$chromeDir = Join-Path $profilePath 'chrome'
$cssTarget = Join-Path $chromeDir 'userChrome.css'
$prefsTarget = Join-Path $profilePath 'user.js'

function Set-ManagedBlock([string]$Path, [string]$Begin, [string]$End, [string]$Body) {
    $existing = if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    $pattern = '(?s)' + [regex]::Escape($Begin) + '.*?' + [regex]::Escape($End) + '\r?\n?'
    $updated = [regex]::Replace($existing, $pattern, '')
    if (-not $Remove) {
        if ($updated.Length -and -not $updated.EndsWith([Environment]::NewLine)) {
            $updated += [Environment]::NewLine
        }
        $updated += $Begin + [Environment]::NewLine + $Body.TrimEnd() +
            [Environment]::NewLine + $End + [Environment]::NewLine
    }
    if ($existing -ceq $updated) { return }
    if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath "$Path.shortcut-ui.bak")) {
        Copy-Item -LiteralPath $Path -Destination "$Path.shortcut-ui.bak"
    }
    $parentDir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir | Out-Null
    }
    [IO.File]::WriteAllText($Path, $updated, $utf8)
}

$cssBody = if ($Remove) { '' } else { [IO.File]::ReadAllText($cssSource) }
Set-ManagedBlock $cssTarget '/* BEGIN SHORTCUT_BRIDGE_FULLSCREEN */' '/* END SHORTCUT_BRIDGE_FULLSCREEN */' $cssBody
$prefsBody = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' + [Environment]::NewLine + 'user_pref("browser.fullscreen.autohide", true);'
Set-ManagedBlock $prefsTarget '// BEGIN SHORTCUT_BRIDGE_FULLSCREEN' '// END SHORTCUT_BRIDGE_FULLSCREEN' $prefsBody

if ($Remove) {
    Write-Host 'Tam ekran UI bloklari kaldirildi; diger ozellestirmeler korundu.'
    Write-Host 'Daha once prefs.js dosyasina islenen tercihler otomatik geri alinmaz.'
} else {
    Write-Host "Tam ekran hover kapatma ayari uygulandi: $profilePath"
    Write-Host 'Waterfox yeniden acildiginda gecerli: F6 paneli gosterir, Esc gizler.'
}
