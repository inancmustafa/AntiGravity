@echo off
REM ===========================================================================
REM SM'i ayrilmis Waterfox profilinde kiosk modunda baslatir.
REM ===========================================================================
REM Bayraklar:
REM   -P "SM"      ayrilmis profil — normal Waterfox profilin etkilenmez
REM   --no-remote  yeni pencere, calisan varsayilan-profil ornegine KATILMASIN
REM   --kiosk      sekme/adres cubugu yok, tarayici UI kisayollarinin cogu kapali,
REM                pencere kimligi sabit
REM
REM DIKKAT: kiosk + kopru = Alt+F4 artik Waterfox'u kapatmaz (Alt SM'e gidiyor).
REM Cikis icin host scriptindeki Ctrl+Alt+Shift+Q kullanilir.
REM ===========================================================================

set "WF=C:\Program Files\Waterfox\waterfox.exe"
set "URL=https://vgpu-secure.fnss.com.tr/portal/webclient/#/desktop"

if not exist "%WF%" (
    echo HATA: Waterfox bulunamadi: "%WF%"
    echo Bridge_Config.ahk ve bu dosyadaki yolu duzelt.
    pause
    exit /b 1
)

start "" "%WF%" -P "SM" --no-remote --kiosk "%URL%"
