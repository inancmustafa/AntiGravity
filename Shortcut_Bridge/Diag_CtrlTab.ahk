#Requires AutoHotkey v2.0
#SingleInstance Force
; HOST ICINDE calistir. Gercek kopruyu logger ile yeniden baslatir.
; SM penceresine tikla, F8 ile hedef olarak isaretle.
; SM'de Diag_SM_Receiver.ahk gercek aliciyi logger ile calistirmali.
; Her makinede loglar: %TEMP%\ShortcutBridgeLogs
Run Format('"{1}" "{2}\Host_PC_Bridge.ahk" diag', A_AhkPath, A_ScriptDir)
ExitApp
