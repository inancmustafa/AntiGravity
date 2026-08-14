# =============================================================================
# SM'e ayrılmış Waterfox profilini oluşturur ve user.js'i içine kopyalar.
# Tek seferlik çalıştırılır. Tekrar çalıştırmak güvenlidir: profil varsa
# yeniden oluşturmaz, yalnızca user.js'i günceller.
# =============================================================================
# Kullanım:  powershell -ExecutionPolicy Bypass -File Setup_SM_Profile.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'

$Waterfox    = 'C:\Program Files\Waterfox\waterfox.exe'
$ProfileName = 'SM'
$ProfilesIni = Join-Path $env:APPDATA 'Waterfox\profiles.ini'
$UserJsSource = Join-Path $PSScriptRoot 'user.js'

if (-not (Test-Path $Waterfox)) {
    throw "Waterfox bulunamadi: $Waterfox"
}
if (-not (Test-Path $UserJsSource)) {
    throw "user.js bulunamadi: $UserJsSource"
}

# --- profiles.ini icinde 'SM' profilini ara ---------------------------------
function Get-SMProfilePath {
    if (-not (Test-Path $ProfilesIni)) { return $null }
    $lines = Get-Content $ProfilesIni
    $name = $null; $path = $null; $isRelative = $null
    foreach ($line in $lines) {
        if ($line -match '^\s*\[') { $name = $null; $path = $null; $isRelative = $null; continue }
        if ($line -match '^\s*Name\s*=\s*(.+?)\s*$')       { $name = $Matches[1] }
        if ($line -match '^\s*Path\s*=\s*(.+?)\s*$')       { $path = $Matches[1] }
        if ($line -match '^\s*IsRelative\s*=\s*(\d)\s*$')  { $isRelative = $Matches[1] }
        if ($name -eq $ProfileName -and $path) {
            if ($isRelative -eq '0') { return $path }
            return (Join-Path (Split-Path $ProfilesIni -Parent) ($path -replace '/', '\'))
        }
    }
    return $null
}

$profilePath = Get-SMProfilePath

if ($profilePath) {
    Write-Host "'$ProfileName' profili zaten var: $profilePath"
} else {
    Write-Host "'$ProfileName' profili olusturuluyor..."
    & $Waterfox '-CreateProfile' $ProfileName | Out-Null
    Start-Sleep -Milliseconds 1500
    $profilePath = Get-SMProfilePath
    if (-not $profilePath) {
        throw "Profil olusturuldu ama profiles.ini'de bulunamadi. Elle olustur: `"$Waterfox`" -P"
    }
    Write-Host "Olusturuldu: $profilePath"
}

if (-not (Test-Path $profilePath)) {
    New-Item -ItemType Directory -Path $profilePath -Force | Out-Null
}

Copy-Item $UserJsSource (Join-Path $profilePath 'user.js') -Force
Write-Host "user.js kopyalandi -> $(Join-Path $profilePath 'user.js')"
Write-Host ''
Write-Host 'Tamamlandi. Simdi Start_SM.cmd ile SM penceresini acabilirsin.'
