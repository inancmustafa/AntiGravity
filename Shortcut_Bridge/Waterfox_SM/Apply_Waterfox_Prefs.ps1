# =============================================================================
# user.js'i MEVCUT Waterfox profiline uygular.
# =============================================================================
# Yeni profil OLUSTURMAZ. Giris yapmis oldugun aktif profili profiles.ini'den
# bulur ve user.js'i oraya kopyalar. Tekrar calistirmak guvenlidir.
#
# Kullanim:  powershell -ExecutionPolicy Bypass -File Apply_Waterfox_Prefs.ps1
#            powershell -ExecutionPolicy Bypass -File Apply_Waterfox_Prefs.ps1 -Remove
# =============================================================================

param([switch]$Remove)

$ErrorActionPreference = 'Stop'

$WaterfoxData  = Join-Path $env:APPDATA 'Waterfox'
$ProfilesIni   = Join-Path $WaterfoxData 'profiles.ini'
$UserJsSource  = Join-Path $PSScriptRoot 'user.js'

if (-not (Test-Path $ProfilesIni)) {
    throw "profiles.ini bulunamadi: $ProfilesIni  (Waterfox'u bir kez ac)"
}

# --- profiles.ini'yi bolumlere ayir ------------------------------------------
$sections = [ordered]@{}
$current  = $null
foreach ($line in Get-Content $ProfilesIni) {
    if ($line -match '^\s*\[(.+?)\]\s*$') {
        $current = $Matches[1]
        $sections[$current] = @{}
        continue
    }
    if ($current -and $line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
        $sections[$current][$Matches[1]] = $Matches[2]
    }
}

function Resolve-ProfileDir($path, $isRelative) {
    if ($isRelative -eq '0') { return $path }
    return (Join-Path $WaterfoxData ($path -replace '/', '\'))
}

# --- Aktif profili bul ------------------------------------------------------
# Modern Gecko, kurulum basina [InstallXXXX] bolumundeki Default= degerini
# kullanir. Yoksa Default=1 isaretli [ProfileN]'e duseriz.
$profileDir  = $null
$profileName = $null

foreach ($name in $sections.Keys) {
    if ($name -like 'Install*' -and $sections[$name]['Default']) {
        $profileDir = Resolve-ProfileDir $sections[$name]['Default'] '1'
        break
    }
}

if (-not $profileDir) {
    foreach ($name in $sections.Keys) {
        if ($name -like 'Profile*' -and $sections[$name]['Default'] -eq '1') {
            $profileDir = Resolve-ProfileDir $sections[$name]['Path'] $sections[$name]['IsRelative']
            break
        }
    }
}

if (-not $profileDir) { throw "profiles.ini icinde aktif profil belirlenemedi." }

# Insan-okunur adi bul
foreach ($name in $sections.Keys) {
    if ($name -like 'Profile*' -and $sections[$name]['Path']) {
        $d = Resolve-ProfileDir $sections[$name]['Path'] $sections[$name]['IsRelative']
        if ($d -eq $profileDir) { $profileName = $sections[$name]['Name']; break }
    }
}

if (-not (Test-Path $profileDir)) { throw "Profil dizini yok: $profileDir" }

Write-Host "Aktif profil : $profileName"
Write-Host "Dizin        : $profileDir"
Write-Host ''

$target = Join-Path $profileDir 'user.js'

if ($Remove) {
    if (Test-Path $target) {
        $installedText = Get-Content -LiteralPath $target -Raw -Encoding UTF8
        if ($installedText -notmatch 'SM KULLANIMI') {
            throw 'user.js kopruya ait degil veya degistirilmis; otomatik kaldirilmadi.'
        }
        if (Test-Path -LiteralPath "$target.bak") {
            Copy-Item -LiteralPath "$target.bak" -Destination $target -Force
        } else {
            Remove-Item -LiteralPath $target -Force
        }
        Write-Host "Kopru user.js kaldirildi veya yedek geri yuklendi. Not: user.js'in daha once yazdigi degerler"
        Write-Host "prefs.js'te KALIR - geri almak icin about:config'den elle duzelt."
    } else {
        Write-Host 'user.js zaten yok.'
    }
    exit 0
}

if (-not (Test-Path $UserJsSource)) { throw "user.js bulunamadi: $UserJsSource" }

if (Test-Path $target) {
    Write-Host 'UYARI: Bu profilde zaten bir user.js var. Iceriginin yedegi aliniyor.'
    if (-not (Test-Path -LiteralPath "$target.bak")) {
        Copy-Item -LiteralPath $target -Destination "$target.bak"
    }
}

Copy-Item $UserJsSource $target -Force
Write-Host "user.js kopyalandi -> $target"

if (Get-Process -Name 'waterfox' -ErrorAction SilentlyContinue) {
    Write-Host ''
    Write-Host 'Waterfox su anda calisiyor. Tercihler BIR SONRAKI acilista gecerli olur.'
}

Write-Host ''
Write-Host 'Uygulanan degisiklikler:'
Write-Host '  - Anasayfa  -> Horizon SM portali'
Write-Host '  - Alt tusu menu cubugunu odaklamasin'
Write-Host '  - Tam ekran uyarisi/animasyonu kapali'
Write-Host ''
Write-Host 'Geri almak icin:  Apply_Waterfox_Prefs.ps1 -Remove'
