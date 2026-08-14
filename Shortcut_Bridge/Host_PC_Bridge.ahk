#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Bridge_Config.ahk

; ==============================================================================
; HOST PC - SM (SANAL MAKİNE) KÖPRÜ SCRIPTI
; ==============================================================================
; HOST PC'de çalışır. SM penceresi (ayrılmış Waterfox) aktifken, host OS'in
; yuttuğu sistem kısayollarını yakalar, yutar ve yerine köprü tuşlarını
; (F13-F24) enjekte eder. Bunlar tarayıcı -> Horizon protokolü -> guest OS
; yolunu izler; SM içindeki Guest_SM_Receiver.ahk bunları gerçek tuşlara çevirir.
;
; Tüm köprü tanımları Bridge_Config.ahk'dedir. Bu dosyada tuş adı sabitlenmez.
;
; ------------------------------------------------------------------------------
; KÖPRÜLENEMEYENLER (bilinçli, "düzeltmeyin")
; ------------------------------------------------------------------------------
; * RAlt / AltGr: KASITLI olarak köprülenmez. Türkçe-Q klavyede AltGr, @ [ ] { }
;   karakterleri için zorunludur; köprülenirse Waterfox'a ve SM'e hiç ulaşmaz ve
;   bu karakterler yazılamaz hale gelir. Bedeli: Alt+Tab yalnızca SOL Alt ile
;   çalışır. Bu bir eksik değil, doğru davranıştır.
; * Win+L: Windows'un sistem düzeyinde ayırdığı bir kısayoldur, AHK engelleyemez.
;   Basarsan HOST kilitlenir, SM değil.
; * Ctrl+Alt+Del: Windows enjekte edilen girdiye kapalıdır (Secure Attention
;   Sequence). Horizon araç çubuğundaki düğmeyi kullan.
; ==============================================================================

SendMode "Event"
SetKeyDelay HOST_KEY_DELAY, HOST_KEY_DELAY
SetTitleMatchMode 2

GroupAdd "SMWindows", SM_WINDOW

; ------------------------------------------------------------------------------
; DURUM
; ------------------------------------------------------------------------------
; Tüm değişken durum tek bir nesnede. Nesne ÖZELLİĞİNE atama yapmak `global`
; bildirimi gerektirmez, dolayısıyla fonksiyonların içinde tek bir `global`
; satırına ihtiyaç yok.
;   held         : basılı köprü tuşu -> basıldığı A_TickCount
;   pendingReset : odak SM'den çıkmışken bir tuş bırakıldı; SM'e dönünce
;                  RESET gönderilecek
; ------------------------------------------------------------------------------
St := { held: Map(), pendingReset: false }

RegisterBridges()
BuildTray()
UpdateTray()
OnExit(OnBridgeExit)
return

; ==============================================================================
; OPERASYON HOTKEY'LERİ
; ==============================================================================
; Suspend'e dahil edilmezler; yoksa köprüyü duraklattıktan sonra geri açamazsın.
#SuspendExempt
^!+s::ToggleSuspend()      ; Köprüyü duraklat / devam ettir
^!+r::PanicRelease()       ; Panik: SM'deki tüm modifier'ları bırak
^!+q::CloseSMWindow()      ; SM penceresini kapat (kiosk modunda tek çıkış)
#SuspendExempt False

; ==============================================================================
; HOTKEY KAYDI
; ==============================================================================
RegisterBridges() {
    ; --- (a) SM penceresi aktifken: Alt down, Win down, tek-vuruşlular --------
    HotIfWinActive "ahk_group SMWindows"
    for e in BRIDGE_TABLE {
        if e.needsAlt
            continue
        handler := (e.mode = "hold") ? HoldDown : TapSend
        for hostKey in e.host
            Hotkey "*" hostKey, handler.Bind(e)
    }
    HotIfWinActive

    ; --- (b) SM penceresi aktif VE Alt köprüsü basılıyken: Tab down, Shift down
    ; Koşul artık GetKeyState("LAlt","P") değil, KÖPRÜ DURUMU. Böylece host'un
    ; fiziksel durumu ile guest'in inandığı durum ayrışamaz.
    ; Alt basılı değilken bu hotkey'ler kayıtlı olmadığı için Tab/Shift
    ; tarayıcıya dokunulmadan geçer.
    altHeldCtx := (hk) => WinActive("ahk_group SMWindows") && St.held.Has(ALT_BRIDGE)
    HotIf altHeldCtx
    for e in BRIDGE_TABLE {
        if !e.needsAlt
            continue
        for hostKey in e.host
            Hotkey "*" hostKey, HoldDown.Bind(e)
    }
    HotIf

    ; --- (c) up olayları: bağlamsız ve GEÇİRMELİ (~) --------------------------
    ; up olayları her yerde yakalanmalı (odak SM'den çıksa bile), ama Alt-up'ı
    ; global olarak YUTMAK host'ta Alt'ı bozar. Köprüleme sırasında Alt-down
    ; zaten yutulmuş olduğu için OS'in eşleşmeyen bir Alt-up görmesi zararsızdır.
    for e in BRIDGE_TABLE {
        if (e.mode != "hold")
            continue
        for hostKey in e.host
            Hotkey "~*" hostKey " up", HoldUp.Bind(e)
    }
}

; ==============================================================================
; KÖPRÜ İŞLEYİCİLERİ
; ==============================================================================
HoldDown(e, *) {
    ; Auto-repeat koruması: tuş basılı tutulurken tekrarlayan down olayları
    ; köprüyü ve Horizon kanalını gereksiz yere doldurur.
    if St.held.Has(e.bridge)
        return
    St.held[e.bridge] := A_TickCount
    SendEvent "{" e.bridge " down}"
    Log("down " e.bridge)
    UpdateTray()
}

HoldUp(e, *) {
    if !St.held.Has(e.bridge)
        return
    St.held.Delete(e.bridge)

    if WinActive("ahk_group SMWindows") {
        SendEvent "{" e.bridge " up}"
        Log("up " e.bridge)
        UpdateTray()
        return
    }

    ; Odak SM penceresinden çıkmış. SendEvent O AN odakta olan pencereye gider;
    ; buradan göndermek (1) alakasız bir uygulamaya kaçak köprü tuşu enjekte
    ; eder, (2) SM'de modifier'ı takılı bırakır. İkisi de olmasın: hiç gönderme,
    ; odak SM'e döndüğünde RESET ile temiz başlat.
    St.pendingReset := true
    SetTimer FlushPendingReset, 250
    Log("up " e.bridge " ERTELENDI (odak SM'de degil)")
    UpdateTray()
}

TapSend(e, *) {
    SendEvent "{" e.bridge "}"
    Log("tap " e.bridge)
}

FlushPendingReset() {
    if !St.pendingReset {
        SetTimer , 0
        return
    }
    if !WinActive("ahk_group SMWindows")
        return                       ; odak dönene kadar beklemeye devam et
    SetTimer , 0
    St.pendingReset := false
    SendReset()
}

SendReset() {
    St.held.Clear()
    if WinExist("ahk_group SMWindows") && WinActive("ahk_group SMWindows")
        SendEvent "{" BRIDGE_RESET "}"
    Log("RESET")
    UpdateTray()
}

; ==============================================================================
; OPERASYON
; ==============================================================================
ToggleSuspend(*) {
    if !A_IsSuspended
        SendReset()              ; duraklatmadan önce SM'i temiz bırak
    Suspend -1
    UpdateTray()
    Notify(A_IsSuspended ? "Köprü DURAKLATILDI" : "Köprü AKTİF")
}

PanicRelease(*) {
    St.pendingReset := false
    SendReset()
    Notify("Tüm köprü tuşları bırakıldı")
}

CloseSMWindow(*) {
    SendReset()
    if !WinExist("ahk_group SMWindows") {
        Notify("SM penceresi bulunamadı")
        return
    }
    WinClose
    if !WinWaitClose("ahk_group SMWindows", , 3) {
        WinKill "ahk_group SMWindows"
        Notify("SM penceresi zorla kapatıldı")
        return
    }
    Notify("SM penceresi kapatıldı")
}

StartSM(*) {
    if WinExist("ahk_group SMWindows") {
        WinActivate
        Notify("SM penceresi zaten açık")
        return
    }
    if !FileExist(SM_BROWSER_EXE) {
        MsgBox "Waterfox bulunamadı:`n" SM_BROWSER_EXE
             . "`n`nBridge_Config.ahk içindeki SM_BROWSER_EXE değerini düzelt."
             , "Shortcut Bridge", "Icon!"
        return
    }
    Run Format('"{1}" -P "{2}" --no-remote --kiosk "{3}"'
             , SM_BROWSER_EXE, SM_PROFILE, SM_URL)
    Notify("SM başlatılıyor…")
}

; ==============================================================================
; TRAY VE GERİ BİLDİRİM
; ==============================================================================
BuildTray() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add "SM'i Başlat", StartSM
    tray.Add "SM Penceresini Kapat`t(Ctrl+Alt+Shift+Q)", CloseSMWindow
    tray.Add
    tray.Add "Modifier'ları Bırak`t(Ctrl+Alt+Shift+R)", PanicRelease
    tray.Add "Duraklat / Devam`t(Ctrl+Alt+Shift+S)", ToggleSuspend
    tray.Add
    tray.Add "Yeniden Yükle", (*) => Reload()
    tray.Add "Çıkış", (*) => ExitApp()
    tray.Default := "SM'i Başlat"
}

UpdateTray() {
    ; A_IconTip 127 karakterle sınırlı; kısa tut.
    heldList := ""
    for bridge, tick in St.held
        heldList .= (heldList = "" ? "" : " ") bridge
    tip := "Shortcut Bridge — " (A_IsSuspended ? "DURAKLATILDI" : "aktif")
    if (heldList != "")
        tip .= "`nBasılı: " heldList
    if St.pendingReset
        tip .= "`nRESET bekliyor"
    A_IconTip := tip
}

Notify(msg, ms := 1500) {
    ToolTip msg
    SetTimer () => ToolTip(), -ms
}

Log(msg) {
    if !DEBUG_LOG
        return
    try FileAppend A_Now " HOST " msg "`n", A_Temp "\shortcut_bridge.log", "UTF-8"
}

OnBridgeExit(*) {
    ; Çıkarken SM'de takılı modifier bırakmamak için son bir RESET.
    SendReset()
}
