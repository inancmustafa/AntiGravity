#Requires AutoHotkey v2.0
#SingleInstance Force
; SM ICINDE calistir. Gercek aliciyi logger ile yeniden baslatir.
Run Format('"{1}" "{2}\Guest_SM_Receiver.ahk" diag', A_AhkPath, A_ScriptDir)
ExitApp
