#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Bridge_Config.ahk

; ==============================================================================
; SM (SANAL MAKİNE) - ALICI SCRIPTI
; ==============================================================================
; SANAL MAKİNENİN İÇİNDE arka planda çalışır. Host PC'den Horizon protokolü
; üzerinden gelen köprü tuşlarını (F13-F24) yakalayıp SM içinde gerçek Windows
; kısayollarını tetikler.
;
; KURULUM: Bu dosya Bridge_Config.ahk ile BİRLİKTE, AYNI KLASÖRE kopyalanmalıdır.
; İkisi tek bir yapılandırmayı paylaşır; ayrı ayrı düzenlenmeleri gerekmez.
;
; BASILI TUTMA MODELİ: Host, Alt/Tab/Shift/Win tuşlarının down/up olaylarını
; ayrı ayrı gönderir. Bu script bunları gerçek tuşun down/up'ına çevirir; böylece
; SM'de Windows'un kendi pencere değiştirici overlay'i açılır, Tab'a art arda
; basılabilir, Alt bırakılınca seçim onaylanır.
;
; TAKILMAYA KARŞI ÜÇ KATMAN:
;   1. Host'un gönderdiği RESET köprü tuşu (odak kaybı / suspend / çıkış).
;   2. Buradaki zaman aşımı watchdog'u (HOLD_TIMEOUT_MS).
;   3. VM içinden basılabilen yerel panik tuşu: Ctrl+Alt+Shift+R.
; ==============================================================================

SendMode "Input"          ; yerel OS'e enjeksiyon — en güvenilir ve atomik
SetKeyDelay -1, -1

; ------------------------------------------------------------------------------
; DURUM
; ------------------------------------------------------------------------------
; Host tarafıyla aynı gerekçe: tüm değişken durum tek nesnede, hiç `global` yok.
;   held         : basılı köprü tuşu -> A_TickCount
;   lastActivity : son köprü olayının zamanı (watchdog bunu kullanır)
; ------------------------------------------------------------------------------
G := { held: Map(), lastActivity: A_TickCount }

RegisterReceivers()
BuildGuestTray()
UpdateGuestTray()
SetTimer GuestWatchdog, 1000
OnExit(OnGuestExit)
return

; ==============================================================================
; YEREL PANİK TUŞU (VM içinden)
; ==============================================================================
#SuspendExempt
^!+r::GuestReset("panik tuşu")
#SuspendExempt False

; ==============================================================================
; HOTKEY KAYDI
; ==============================================================================
RegisterReceivers() {
    for e in BRIDGE_TABLE {
        if (e.mode = "hold") {
            Hotkey "*" e.bridge,       GuestHoldDown.Bind(e)
            Hotkey "*" e.bridge " up", GuestHoldUp.Bind(e)
        } else {
            Hotkey "*" e.bridge,       GuestTap.Bind(e)
        }
    }
    Hotkey "*" BRIDGE_RESET, (*) => GuestReset("host RESET")
}

; ==============================================================================
; KÖPRÜ İŞLEYİCİLERİ
; ==============================================================================
GuestHoldDown(e, *) {
    G.lastActivity := A_TickCount

    ; Auto-repeat koruması — aynı köprü tuşu iki kez down gelirse yoksay.
    if G.held.Has(e.bridge)
        return

    ; needsAlt: Alt köprüsü basılı değilken bu tuş anlamsız.
    ; Sıra bozulmuş olabilir (ağ jitter'ı yüzünden F14, F13'ten önce gelmiş).
    ; Kullanıcı bunu "Alt+Tab bir pencere atladı" diye yaşar, o yüzden sessizce
    ; düşürmek yerine logla.
    if (e.needsAlt && !G.held.Has(ALT_BRIDGE)) {
        GuestLog("DUSTU " e.bridge " (Alt kopru tusu basili degil)")
        return
    }

    G.held[e.bridge] := A_TickCount
    Send "{" e.guest " down}"

    ; Overlay'in açılması için gerekirse mikro-bekleme. Varsayılan 0;
    ; overlay açılmıyorsa Bridge_Config.ahk'de GUEST_SETTLE_MS'i artır.
    if (e.guest = "Alt" && GUEST_SETTLE_MS > 0)
        Sleep GUEST_SETTLE_MS

    UpdateGuestTray()
}

GuestHoldUp(e, *) {
    G.lastActivity := A_TickCount
    if !G.held.Has(e.bridge)
        return
    G.held.Delete(e.bridge)
    Send "{" e.guest " up}"
    UpdateGuestTray()
}

GuestTap(e, *) {
    G.lastActivity := A_TickCount
    Send e.guest              ; tek-vuruşlularda guest bir Send dizisidir ("^w")
    GuestLog("tap " e.bridge " -> " e.guest)
}

; ==============================================================================
; SIFIRLAMA
; ==============================================================================
GuestReset(reason := "") {
    G.lastActivity := A_TickCount

    ; Tabloyu TERS sırada gez: Win/Shift/Tab önce, Alt en son bırakılsın.
    ; Alt'ı ilk bıraksaydık overlay seçimi onaylanır ve istenmeyen pencere
    ; değişimi olurdu.
    loop BRIDGE_TABLE.Length {
        e := BRIDGE_TABLE[BRIDGE_TABLE.Length - A_Index + 1]
        if (e.mode = "hold" && G.held.Has(e.bridge))
            Send "{" e.guest " up}"
    }
    G.held.Clear()

    ; Emniyet kemeri: tabloda izlenmese bile mantıksal olarak basılı kalmış
    ; bir modifier varsa onu da bırak.
    for key in ["Alt", "Ctrl", "Shift", "LWin", "RWin"]
        if GetKeyState(key)
            Send "{" key " up}"

    GuestLog("RESET (" reason ")")
    UpdateGuestTray()
    if (reason != "host RESET")
        GuestNotify("Köprü sıfırlandı — " reason)
}

GuestWatchdog() {
    if (G.held.Count && (A_TickCount - G.lastActivity > HOLD_TIMEOUT_MS))
        GuestReset("zaman aşımı")
}

; ==============================================================================
; TRAY VE GERİ BİLDİRİM
; ==============================================================================
BuildGuestTray() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add "Modifier'ları Bırak`t(Ctrl+Alt+Shift+R)", (*) => GuestReset("tray")
    tray.Add
    tray.Add "Yeniden Yükle", (*) => Reload()
    tray.Add "Çıkış", (*) => ExitApp()
    tray.Default := "Modifier'ları Bırak`t(Ctrl+Alt+Shift+R)"
}

UpdateGuestTray() {
    heldList := ""
    for bridge, tick in G.held
        heldList .= (heldList = "" ? "" : " ") bridge
    tip := "SM Alıcı — " (A_IsSuspended ? "DURAKLATILDI" : "aktif")
    if (heldList != "")
        tip .= "`nBasılı: " heldList
    A_IconTip := tip
}

GuestNotify(msg, ms := 2000) {
    ToolTip msg
    SetTimer () => ToolTip(), -ms
}

GuestLog(msg) {
    if !DEBUG_LOG
        return
    try FileAppend A_Now " GUEST " msg "`n", A_Temp "\shortcut_bridge.log", "UTF-8"
}

OnGuestExit(*) {
    GuestReset("çıkış")
}
