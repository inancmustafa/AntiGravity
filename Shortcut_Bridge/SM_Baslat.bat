@echo off
REM ===========================================================================
REM SM KOPRULU BASLATMA
REM ===========================================================================
REM Bu bat ile baslatirsan:
REM   - Kopru scripti (Host_PC_Bridge.ahk) calisir
REM   - Waterfox penceresini kopru KENDISI acar ve SM linkine gider
REM   - Pencere tam ekrana (F11) gecer
REM   - YALNIZCA o pencere koprulenir; elle actigin diger Waterfox
REM     pencerelerinde Alt+Tab ve Win normal calismaya devam eder
REM
REM Waterfox'u kendin acarsan: SM linki acilir (anasayfa), tam ekran olmaz,
REM kopru calismaz. Onun icin bu bat'a gerek yok.
REM
REM Cikis: tray ikonundan Cikis, veya Ctrl+Alt+Shift+Q ile yalnizca SM
REM penceresini kapat. (Kopru calisirken Alt+F4 SM'e gider!)
REM ===========================================================================

setlocal

set "AHK=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
if not exist "%AHK%" set "AHK=C:\Program Files\AutoHotkey\v2\AutoHotkey32.exe"
if not exist "%AHK%" set "AHK=C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"

if not exist "%AHK%" (
    echo HATA: AutoHotkey v2 bulunamadi.
    echo Beklenen konum: C:\Program Files\AutoHotkey\v2\
    echo https://www.autohotkey.com/ adresinden v2 kur.
    pause
    exit /b 1
)

if not exist "%~dp0Host_PC_Bridge.ahk" (
    echo HATA: Host_PC_Bridge.ahk bulunamadi: "%~dp0"
    pause
    exit /b 1
)

start "" "%AHK%" "%~dp0Host_PC_Bridge.ahk" sm

endlocal
