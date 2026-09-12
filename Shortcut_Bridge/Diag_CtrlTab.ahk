#Requires AutoHotkey v2.0
#SingleInstance Force
; Gercek Host_PC_Bridge.ahk'yi tani modunda baslatir; ayri F18 yolu yoktur.
; Host'taki mevcut kopru instance'i bununla degistirilir.
; SM'de Guest_SM_Receiver yerine Test_ShowKeys acikken Ctrl+Alt+Shift+M ile
; SM penceresini isaretle. Ctrl+Tab/Ctrl+Shift+Tab F14 down/up uretmelidir.
; Test_ShowKeys'te F14 sirasinda Ctrl/Shift durumunu kontrol et.
; Host olaylari tooltip'te ve %TEMP%\shortcut_bridge.log dosyasindadir.
; Bitince host tray -> Cikis; normal kullanim icin SM_Baslat.bat.
Run Format('"{1}" "{2}\Host_PC_Bridge.ahk" diag', A_AhkPath, A_ScriptDir)
ExitApp
