#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Bridge_Config.ahk
#Include Bridge_Logger.ahk

; ==============================================================================
; HOST PC - SM (SANAL MAKİNE) KÖPRÜ SCRIPTI
; ==============================================================================
; HOST PC'de çalışır. SM penceresi aktifken, host OS'in yuttuğu sistem
; kısayollarını yakalar, yutar ve yerine köprü tuşlarını (F13-F24) enjekte eder.
; Bunlar tarayıcı -> Horizon protokolü -> guest OS yolunu izler; SM içindeki
; Guest_SM_Receiver.ahk bunları gerçek tuşlara çevirir.
;
; ------------------------------------------------------------------------------
; İKİ KULLANIM MODU
; ------------------------------------------------------------------------------
; 1. SM_Baslat.bat ile başlatılır (argüman: "sm")
;    -> Bu script Waterfox penceresini KENDİSİ açar, HWND'sini hatırlar,
;       tam ekrana geçirir ve YALNIZCA o pencereyi köprüler.
;
; 2. Waterfox'u kendin açarsın
;    -> Bu script çalışmıyorsa hiçbir şey köprülenmez. Çalışıyor olsa bile
;       yalnızca kendi açtığı pencereyi köprülediği için senin pencerene
;       dokunmaz: Alt+Tab, Win normal çalışır.
;
; Elle açtığın bir pencereyi sonradan köprüye bağlamak: Ctrl+Alt+Shift+M
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

; ------------------------------------------------------------------------------
; DURUM
; ------------------------------------------------------------------------------
; Tüm değişken durum tek bir nesnede. Nesne ÖZELLİĞİNE atama yapmak `global`
; bildirimi gerektirmez, dolayısıyla fonksiyonların içinde tek bir `global`
; satırına ihtiyaç yok.
;   smHwnd       : köprülenecek TEK pencerenin handle'ı. 0 ise köprü pasiftir.
;   held         : basılı köprü tuşu -> basıldığı A_TickCount
;   pendingReset : odak SM'den çıkmışken bir tuş bırakıldı; SM'e dönünce
;                  RESET gönderilecek
; ------------------------------------------------------------------------------
St := { smHwnd: 0, held: Map(), sources: Map(), pendingReset: false,
        lastKeepalive: 0, wasActive: false,
        diagnostic: A_Args.Length >= 1 && A_Args[1] = "diag" }

RegisterBridges()
BuildTray()
UpdateTray()
SetTimer CheckSMWindow, 2000
SetTimer MaintainBridge, 100
OnExit(OnBridgeExit)
TraceStart("HOST", DEBUG_LOG || St.diagnostic)
Log("START target=" St.smHwnd " diagnostic=" St.diagnostic)
if St.diagnostic {
    HotIf (*) => St.diagnostic
    Hotkey "F8", MarkActiveAsSM
    HotIf
    Notify("LOGGER AKTIF: SM penceresine tikla, F8 ile bagla.", 7000)
}

; SM_Baslat.bat "sm" argümanıyla çağırır -> pencereyi hemen aç.
if (A_Args.Length >= 1 && A_Args[1] = "sm")
    StartSM()
else if !St.diagnostic
    Notify("Kopru PASIF: SM_Baslat.bat kullan veya SM penceresini Ctrl+Alt+Shift+M ile bagla.", 7000)
return

; ==============================================================================
; OPERASYON HOTKEY'LERİ
; ==============================================================================
; Suspend'e dahil edilmezler; yoksa köprüyü duraklattıktan sonra geri açamazsın.
#SuspendExempt
^!+s::ToggleSuspend()       ; Köprüyü duraklat / devam ettir
^!+r::PanicRelease()        ; Panik: SM'deki tüm modifier'ları bırak
^!+q::CloseSMWindow()       ; SM penceresini kapat
^!+m::MarkActiveAsSM()      ; Aktif pencereyi SM penceresi olarak işaretle
#SuspendExempt False

; ==============================================================================
; SM PENCERESİ
; ==============================================================================
; Köprünün tamamı buna bağlı: yalnızca St.smHwnd penceresi aktifken tetiklenir.
; Kendi açtığın diğer Waterfox pencereleri farklı HWND'ye sahip olduğu için
; hiç etkilenmez.
IsSM() {
    if !St.smHwnd
        return false
    return WinActive("ahk_id " St.smHwnd) ? true : false
}

; Pencere kapandıysa köprüyü pasifleştir — yoksa HWND yeniden kullanılabilir ve
; alakasız bir pencere köprülenmeye başlar.
CheckSMWindow() {
    if (St.smHwnd && !WinExist("ahk_id " St.smHwnd)) {
        St.smHwnd := 0
        St.held.Clear()
        St.sources.Clear()
        St.pendingReset := false
        UpdateTray()
        Notify("SM penceresi kapandı — köprü pasif")
    }
}

; ==============================================================================
; HOTKEY KAYDI
; ==============================================================================
RegisterBridges() {
    ; --- Bağlam ("gate") callback'leri ---------------------------------------
    ; Değişkende/Map'te tutuluyorlar çünkü AHK v2'de her AYRI callback nesnesi
    ; ayrı bir hotkey varyant grubu oluşturur; aynı nesneyi paylaşan hotkey'ler
    ; aynı gruba girer. Bir gate = bir callback nesnesi.
    ;
    ; "mod" kapısı bu tasarımın can alıcı noktası: Tab için host'ta YALNIZCA
    ; TEK hotkey (`*Tab`) kayıtlı olmalı. Daha önce Alt+Tab için `*Tab`,
    ; Ctrl+Tab için ayrı bir `^Tab` kayıtlıydı; AHK Ctrl+Tab'da ikisi arasında
    ; seçim yapmak zorunda kaldı, wildcard `*Tab` öne geçti, varyantı pasif
    ; olduğu için tuş hiç yakalanmadan geçti ve `^Tab` sıraya bile gelmedi.
    ; İki durumu tek kapıda birleştirmek bu belirsizliği yok eder.
    ;
    ; Alt koşulu KÖPRÜ DURUMUNA bakar (fiziksel tuşa değil) — böylece host'un
    ; fiziksel durumu ile guest'in inandığı durum ayrışamaz. Ctrl ise
    ; köprülenmediği için fiziksel duruma bakmak zorundayız.
    gates := Map(
        "",    (hk) => BridgeReady(),
        "alt", (hk) => BridgeReady() && St.held.Has(ALT_BRIDGE),
        "mod", (hk) => BridgeReady() && (St.held.Has(ALT_BRIDGE) || GetKeyState("Ctrl", "P"))
    )

    ; --- down / tap olayları: kendi kapılarının altında ----------------------
    for gateName, gateFn in gates {
        HotIf gateFn
        for e in BRIDGE_TABLE {
            if (e.gate != gateName)
                continue
            if (e.mode = "hold") {
                ; hold: `*` şart — tuş, başka modifier'lar basılı olsa da
                ; yakalanmalı (Ctrl+Tab'da Ctrl, Alt+Shift+Tab'da Shift basılı).
                for hostKey in e.host
                    Hotkey "*" hostKey, HoldDown.Bind(e, hostKey)
            } else {
                ; tap: hotkey dizesi OLDUĞU GİBİ kaydedilir, `*` EKLENMEZ.
                ; Wildcard eklemek fazladan modifier'lı varyantları da yakalar
                ; ve spesifik girdilerle çakışır.
                for hostKey in e.host
                    Hotkey hostKey, TapSend.Bind(e)
            }
        }
        HotIf
    }

    ; --- up olayları: hedefte yut, diğer pencerelerde geçir ------------------
    ; Takip edilen kaynak hedefte bırakılıyorsa doğal up sızmamalı.
    ; Bağlamsız ~ varyantı diğer pencerelerde normal klavye davranışını korur.
    for e in BRIDGE_TABLE {
        if (e.mode != "hold")
            continue
        for hostKey in e.host {
            ; Koprulenmis down'in up'i da SM odagindayken yutulur.
            ; Aksi halde dogal Shift-up, diger Shift halen basiliyken
            ; guest'in koprulenmis Shift durumunu silebilir.
            HotIf SourceReleaseReady.Bind(hostKey)
            Hotkey "*" hostKey " up", HoldUp.Bind(e, hostKey)
            HotIf
            Hotkey "~*" hostKey " up", HoldUp.Bind(e, hostKey)
        }
    }
}

; ==============================================================================
; KÖPRÜ İŞLEYİCİLERİ
; ==============================================================================
HoldDown(e, hostKey, *) {
    Critical
    Log("HANDLER_DOWN key=" hostKey " bridge=" e.bridge " ready=" BridgeReady())
    if !BridgeReady()
        return
    St.wasActive := true
    St.sources[hostKey] := e.bridge
    ; AUTO-REPEAT KORUMASI: tuş basılı tutulurken Windows down olayını tekrar
    ; tekrar üretir. Guard olmasa her tekrar yeni bir {F13 down} gönderir ve
    ; Horizon kanalı dolar. Bu guard sayesinde Alt basılı tutmak tek bir
    ; {F13 down} üretir.
    if St.held.Has(e.bridge)
        return
    St.held[e.bridge] := A_TickCount
    SendEvent "{Blind}{" e.bridge " down}"
    Log("down " e.bridge)
    UpdateTray()
}

HoldUp(e, hostKey, *) {
    Critical
    Log("HANDLER_UP key=" hostKey " bridge=" e.bridge " tracked=" St.sources.Has(hostKey))
    if !St.sources.Has(hostKey)
        return
    St.sources.Delete(hostKey)
    ; Sol/sag tuslar ayni kopruyu paylasir; son kaynak birakilana kadar tut.
    for source, bridge in St.sources
        if (bridge = e.bridge)
            return
    if !St.held.Has(e.bridge)
        return
    St.held.Delete(e.bridge)

    if IsSM() {
        SendEvent "{Blind}{" e.bridge " up}"
        Log("up " e.bridge)
        UpdateTray()
        return
    }

    ; Odak SM penceresinden çıkmış. SendEvent O AN odakta olan pencereye gider;
    ; buradan göndermek (1) alakasız bir uygulamaya kaçak köprü tuşu enjekte
    ; eder, (2) SM'de modifier'ı takılı bırakır. İkisi de olmasın: hiç gönderme,
    ; odak SM'e döndüğünde RESET ile temiz başlat.
    SendReset()
    Log("up " e.bridge " ERTELENDI (odak SM'de degil)")
    UpdateTray()
}

TapSend(e, *) {
    Critical
    if !BridgeReady()
        return
    ; {Blind} ZORUNLU: fiziksel modifier durumuna dokunmadan gönder.
    ; Ctrl+W gibi tap girdilerinde Ctrl doğal yoldan iletilir.
    ; HoldDown/HoldUp ile aynı Blind ilkesi burada da uygulanır.
    SendEvent "{Blind}{" e.bridge "}"
    Log("tap " e.bridge)
}

FlushPendingReset() {
    if (St.pendingReset && IsSM())
        SendReset()
}

SendReset() {
    Critical
    St.held.Clear()
    St.sources.Clear()
    St.pendingReset := St.smHwnd != 0
    if IsSM() {
        SendEvent "{Blind}{" BRIDGE_RESET "}"
        St.pendingReset := false
    }
    Log("RESET")
    UpdateTray()
}

SourceReleaseReady(hostKey, *) {
    return IsSM() && St.sources.Has(hostKey)
}

BridgeReady() {
    return IsSM() && !St.pendingReset
}

MaintainBridge() {
    Critical
    active := IsSM()
    if Trace.enabled {
        hwnd := WinExist("A")
        exe := ""
        try exe := WinGetProcessName("ahk_id " hwnd)
        state := "target=" St.smHwnd " foreground=" hwnd " exe=" exe
            . " matched=" active " pending=" St.pendingReset " suspended=" A_IsSuspended
            . " held=" St.held.Count " " TraceModifiers()
        if (state != Trace.lastState) {
            Trace.lastState := state
            TraceWrite("STATE", state)
        }
    }
    if (!active && St.wasActive && St.held.Count)
        SendReset()
    St.wasActive := active
    FlushPendingReset()
    if (!active || A_IsSuspended || St.pendingReset || !St.held.Count)
        return
    ; Bir up olayi kaybolduysa fiziksel durumla uzlastir; hayalet tutusa
    ; sonsuza kadar canlilik sinyali gonderme.
    for e in BRIDGE_TABLE {
        if (e.mode != "hold")
            continue
        for hostKey in e.host
            if (St.sources.Has(hostKey) && !GetKeyState(hostKey, "P"))
                HoldUp(e, hostKey)
    }
    if !St.held.Count
        return
    if (A_TickCount - St.lastKeepalive >= KEEPALIVE_MS) {
        SendEvent "{Blind}{" BRIDGE_KEEPALIVE "}"
        St.lastKeepalive := A_TickCount
    }
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
    SendReset()
    Notify(St.pendingReset ? "RESET, SM odagina donunce gonderilecek" : "Tum kopru tuslari birakildi")
}

MarkActiveAsSM(*) {
    hwnd := WinGetID("A")
    if !hwnd {
        Notify("Aktif pencere bulunamadı")
        return
    }
    if (St.diagnostic && StrLower(WinGetProcessName("ahk_id " hwnd)) != "waterfox.exe") {
        Log("MARK_REJECT foreground is not Waterfox")
        Notify("Once SM'nin Waterfox penceresine tikla, sonra F8.", 4000)
        return
    }
    SendReset()
    St.smHwnd := hwnd
    St.pendingReset := true
    Log("MARK target=" hwnd)
    UpdateTray()
    Notify("SM penceresi işaretlendi: " WinGetProcessName("A"))
}

CloseSMWindow(*) {
    SendReset()
    if (!St.smHwnd || !WinExist("ahk_id " St.smHwnd)) {
        Notify("SM penceresi yok")
        return
    }
    hwnd := St.smHwnd
    WinClose "ahk_id " hwnd
    if !WinWaitClose("ahk_id " hwnd, , 3) {
        WinKill "ahk_id " hwnd
        Notify("SM penceresi zorla kapatıldı")
    } else {
        Notify("SM penceresi kapatıldı")
    }
    St.smHwnd := 0
    UpdateTray()
}

; ------------------------------------------------------------------------------
; SM penceresini aç ve HWND'sini yakala.
; Waterfox tek profille çalıştığı için ikinci bir örnek başlatılamaz; yeni
; pencere mevcut sürecin içinde açılır. Bu yüzden PID ile ayırt etmek işe
; yaramaz — açılış ÖNCESİ ve SONRASI pencere listesi karşılaştırılır.
; ------------------------------------------------------------------------------
StartSM(*) {
    if (St.smHwnd && WinExist("ahk_id " St.smHwnd)) {
        WinActivate "ahk_id " St.smHwnd
        Notify("SM penceresi zaten açık")
        return
    }
    if !FileExist(SM_BROWSER_EXE) {
        MsgBox "Waterfox bulunamadı:`n" SM_BROWSER_EXE
             . "`n`nBridge_Config.ahk içindeki SM_BROWSER_EXE değerini düzelt."
             , "Shortcut Bridge", "Icon!"
        return
    }

    before := Map()
    for hwnd in WinGetList("ahk_exe waterfox.exe")
        before[hwnd] := true

    Run Format('"{1}" --new-window "{2}"', SM_BROWSER_EXE, SM_URL)

    found := WaitForNewWaterfoxWindow(before)
    if !found {
        Notify("Yeni Waterfox penceresi bulunamadı.`n"
             . "Pencereye tıklayıp Ctrl+Alt+Shift+M ile elle işaretle.", 5000)
        return
    }

    St.smHwnd := found
    WinActivate "ahk_id " found
    UpdateTray()

    if SM_FULLSCREEN {
        Sleep SM_FULLSCREEN_DELAY_MS
        if WinActive("ahk_id " found)
            SendEvent "{F11}"        ; köprülenmemiş tuş — doğrudan tarayıcıya gider
    }
    Notify("SM köprüsü aktif")
}

WaitForNewWaterfoxWindow(before) {
    deadline := A_TickCount + SM_LAUNCH_TIMEOUT_MS
    while (A_TickCount < deadline) {
        Sleep 250
        for hwnd in WinGetList("ahk_exe waterfox.exe")
            if !before.Has(hwnd)
                return hwnd
    }
    return 0
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
    tray.Add "Logger ile yeniden baslat", (*) => Run(Format('"{1}" "{2}" diag', A_AhkPath, A_ScriptFullPath))
    tray.Add "Log klasorunu ac", TraceOpenFolder
    tray.Add "Yeniden Yükle", (*) => Reload()
    tray.Add "Çıkış", (*) => ExitApp()
    tray.Default := "SM'i Başlat"
}

UpdateTray() {
    ; A_IconTip 127 karakterle sınırlı; kısa tut.
    heldList := ""
    for bridge, tick in St.held
        heldList .= (heldList = "" ? "" : " ") bridge

    if A_IsSuspended
        state := "DURAKLATILDI"
    else if !St.smHwnd
        state := "pasif (SM penceresi yok)"
    else
        state := "aktif"

    tip := "Shortcut Bridge v" BRIDGE_PROTOCOL_VERSION " — " state
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
    if Trace.enabled
        TraceWrite("BRIDGE", msg " target=" St.smHwnd " matched=" IsSM()
            . " pending=" St.pendingReset " " TraceModifiers())
}

OnBridgeExit(*) {
    ; Çıkarken SM'de takılı modifier bırakmamak için son bir RESET.
    SendReset()
}
