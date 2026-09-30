#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Bridge_Config.ahk
#Include Bridge_Logger.ahk

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
; TEK WIN: Win'e tek basışta host F16 down/up gönderir. Bırakma anında F16-up
; olayı Win down ile Win up arasına girdiği için Windows bunu "tek Win" saymaz ve
; Başlat menüsü açılmaz (host üzerinde ölçüldü). Win basılıyken başka bir tuş
; gelmediyse alıcı, bıraktıktan sonra temiz bir Win vuruşu ekler
; (GUEST_WIN_TAP_FIX). Win+D gibi kombinasyonlarda ek vuruş yapılmaz.
;
; OTURUM AÇILIŞINDA BAŞLATMA: tray > "Oturum açılışında başlat". Başlangıç
; klasörüne kısayol koyar; AutoHotkey'in UI Access sürümü kuruluysa onu kullanır,
; böylece yönetici olarak açılmış pencerelerde de çalışır.
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
G := { held: Map(), lastActivity: A_TickCount, winCombo: false, winWatch: 0,
       diagnostic: A_Args.Length >= 1 && A_Args[1] = "diag" }

AUTOSTART_MENU := "Oturum açılışında başlat"
AUTOSTART_LINK := "Shortcut Bridge SM Alici.lnk"

RegisterReceivers()
StartWinComboWatch()
BuildGuestTray()
UpdateGuestTray()
SetTimer GuestWatchdog, 1000
OnExit(OnGuestExit)
TraceStart("GUEST", DEBUG_LOG || G.diagnostic)
GuestLog("START")
return

; ==============================================================================
; YEREL PANİK TUŞU (VM içinden)
; ==============================================================================
#SuspendExempt
^!+r::GuestReset("panik tuşu", true)
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
    Hotkey "*" BRIDGE_KEEPALIVE, GuestKeepalive
    Hotkey "*" BRIDGE_KEEPALIVE " up", (*) => 0
}

; ==============================================================================
; KÖPRÜ İŞLEYİCİLERİ
; ==============================================================================
; ------------------------------------------------------------------------------
; {Blind} HER YERDE ZORUNLU
; ------------------------------------------------------------------------------
; {Blind} = "mevcut modifier durumuna dokunma, tuşu olduğu gibi bas".
; Bu sayede bu script hangi modifier'ın basılı olduğunu BİLMEK ZORUNDA DEĞİL:
;   * Alt+Tab       -> Alt burada basılı (F13 köprüsüyle)  -> {Blind}{Tab} = Alt+Tab
;   * Ctrl+Tab      -> Ctrl burada basılı (doğal iletimle) -> {Blind}{Tab} = Ctrl+Tab
;   * Ctrl+Shift+Tab-> Ctrl ve Shift doğal iletimle        -> bedava çalışır
; Blind olmasa AHK, Tab'ı "yalnız Tab" yapmak için basılı modifier'ları bırakıp
; geri basardı; bu sahte modifier-up üretip kombinasyonu bozardı.
;
; Hangi durumda köprülenip köprülenmeyeceği kararı HOST tarafında (`gate` alanı)
; verilir. Buraya ulaşan köprü tuşu zaten geçerlidir, ek koşul aranmaz.
; ------------------------------------------------------------------------------
GuestHoldDown(e, *) {
    Critical
    GuestLog("RX_DOWN " e.bridge)
    G.lastActivity := A_TickCount

    ; Auto-repeat koruması — aynı köprü tuşu iki kez down gelirse yoksay.
    if G.held.Has(e.bridge)
        return

    ; Tek Win takibi: Win tutuşu yeni başlıyor ya da Win basılıyken başka bir
    ; köprü tuşu geldi (ör. Win+Alt).
    if (e.bridge = WIN_BRIDGE)
        G.winCombo := false
    else if G.held.Has(WIN_BRIDGE)
        G.winCombo := true

    G.held[e.bridge] := A_TickCount
    Send "{Blind}{" e.guest " down}"
    GuestLog("TX_DOWN " e.bridge " -> " e.guest)

    ; Overlay'in açılması için gerekirse mikro-bekleme. Varsayılan 0;
    ; overlay açılmıyorsa Bridge_Config.ahk'de GUEST_SETTLE_MS'i artır.
    if (e.guest = "Alt" && GUEST_SETTLE_MS > 0)
        Sleep GUEST_SETTLE_MS

    UpdateGuestTray()
}

GuestHoldUp(e, *) {
    Critical
    GuestLog("RX_UP " e.bridge)
    G.lastActivity := A_TickCount
    if !G.held.Has(e.bridge)
        return
    G.held.Delete(e.bridge)
    Send "{Blind}{" e.guest " up}"
    GuestLog("TX_UP " e.bridge " -> " e.guest)
    if (e.bridge = WIN_BRIDGE && GUEST_WIN_TAP_FIX && !G.winCombo) {
        ; Yukarıdaki bırakma Başlat'ı açmaz (F16-up araya girdi); temiz vuruş aç.
        Send "{Blind}{" e.guest "}"
        GuestLog("TX_TAP " e.guest " (tek Win)")
    }
    UpdateGuestTray()
}

GuestTap(e, *) {
    Critical
    G.lastActivity := A_TickCount
    if G.held.Has(WIN_BRIDGE)
        G.winCombo := true
    ; Modifier zaten doğal olarak iletildiği için yalnızca temel tuşu basıyoruz.
    Send "{Blind}{" e.guest "}"
    GuestLog("tap " e.bridge " -> " e.guest)
}

; ==============================================================================
; SIFIRLAMA
; ==============================================================================
GuestReset(reason := "", allModifiers := false) {
    Critical
    G.lastActivity := A_TickCount

    ; Tabloyu TERS sırada gez: Win/Shift/Tab önce, Alt en son bırakılsın.
    ; Alt'ı ilk bıraksaydık overlay seçimi onaylanır ve istenmeyen pencere
    ; değişimi olurdu.
    loop BRIDGE_TABLE.Length {
        e := BRIDGE_TABLE[BRIDGE_TABLE.Length - A_Index + 1]
        if (e.mode = "hold" && G.held.Has(e.bridge))
            Send "{Blind}{" e.guest " up}"
    }
    G.held.Clear()

    ; Emniyet kemeri: tabloda izlenmese bile mantıksal olarak basılı kalmış
    ; bir modifier varsa onu da bırak.
    ; Normal RESET dogal Ctrl/AltGr durumunu bozmamali.
    ; Tum modifier'lari birakmak yalnizca yerel panik/tray islemidir.
    if allModifiers
        for key in ["LAlt", "RAlt", "LCtrl", "RCtrl", "LShift", "RShift", "LWin", "RWin"]
            if GetKeyState(key)
                Send "{Blind}{" key " up}"

    GuestLog("RESET (" reason ")")
    UpdateGuestTray()
    if (reason != "host RESET")
        GuestNotify("Köprü sıfırlandı — " reason)
}

; ------------------------------------------------------------------------------
; Win basılıyken doğal kanaldan (Horizon) gelen herhangi bir tuş Win'i kombinasyon
; yapar (Win+D, Win+Shift+S...). Görünür (V) hook tuşları engellemez; I seçeneği
; bu scriptin kendi gönderimlerini yok sayar. Köprü tuşları GuestHoldDown'da
; ayrıca işlenir.
; ------------------------------------------------------------------------------
StartWinComboWatch() {
    if (!GUEST_WIN_TAP_FIX || WIN_BRIDGE = "")
        return
    ih := InputHook("V I L0")
    ih.KeyOpt("{All}", "N")
    for e in BRIDGE_TABLE
        ih.KeyOpt("{" e.bridge "}", "-N")
    ih.KeyOpt("{" BRIDGE_RESET "}{" BRIDGE_KEEPALIVE "}{LWin}{RWin}", "-N")
    ih.OnKeyDown := WinComboKey
    ih.Start()
    G.winWatch := ih
}

WinComboKey(ih, vk, sc) {
    if G.held.Has(WIN_BRIDGE)
        G.winCombo := true
}

GuestWatchdog() {
    Critical
    if (G.held.Count && (A_TickCount - G.lastActivity > HOLD_TIMEOUT_MS))
        GuestReset("zaman aşımı")
}

; ==============================================================================
; TRAY VE GERİ BİLDİRİM
; ==============================================================================
GuestKeepalive(*) {
    G.lastActivity := A_TickCount
}

BuildGuestTray() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add "Modifier'ları Bırak`t(Ctrl+Alt+Shift+R)", (*) => GuestReset("tray", true)
    tray.Add
    tray.Add AUTOSTART_MENU, ToggleGuestAutostart
    if FileExist(GuestAutostartPath())
        tray.Check AUTOSTART_MENU
    tray.Add
    tray.Add "Logger ile yeniden baslat", (*) => Run(Format('"{1}" "{2}" diag', A_AhkPath, A_ScriptFullPath))
    tray.Add "Log klasorunu ac", TraceOpenFolder
    tray.Add "Yeniden Yükle", (*) => Reload()
    tray.Add "Çıkış", (*) => ExitApp()
    tray.Default := "Modifier'ları Bırak`t(Ctrl+Alt+Shift+R)"
}

UpdateGuestTray() {
    heldList := ""
    for bridge, tick in G.held
        heldList .= (heldList = "" ? "" : " ") bridge
    tip := "SM Alici v" BRIDGE_PROTOCOL_VERSION " — " (A_IsSuspended ? "DURAKLATILDI" : "aktif")
    if (heldList != "")
        tip .= "`nBasılı: " heldList
    A_IconTip := tip
}

; ------------------------------------------------------------------------------
; OTURUM AÇILIŞINDA BAŞLATMA
; ------------------------------------------------------------------------------
GuestAutostartPath(folder := A_Startup) {
    return folder "\" AUTOSTART_LINK
}

; UI Access sürümü (AutoHotkey kurulumunda seçildiyse) yönetici pencerelerinde de
; hotkey/Send çalıştırır; scripti yönetici yapmadan. Yoksa mevcut yorumlayıcı.
GuestAutostartExe() {
    uia := RegExReplace(A_AhkPath, "i)(?<!_UIA)\.exe$", "_UIA.exe")
    return FileExist(uia) ? uia : A_AhkPath
}

SetGuestAutostart(enable, folder := A_Startup) {
    link := GuestAutostartPath(folder)
    if !enable {
        if FileExist(link)
            FileDelete link
        return false
    }
    FileCreateShortcut GuestAutostartExe(), link, A_ScriptDir
        , '"' A_ScriptFullPath '"', "Shortcut Bridge SM alicisi"
    return true
}

ToggleGuestAutostart(*) {
    enabled := SetGuestAutostart(!FileExist(GuestAutostartPath()))
    if enabled
        A_TrayMenu.Check AUTOSTART_MENU
    else
        A_TrayMenu.Uncheck AUTOSTART_MENU
    GuestNotify(enabled ? "Oturum açılışında başlayacak" : "Otomatik başlatma kapatıldı")
}

GuestNotify(msg, ms := 2000) {
    ToolTip msg
    SetTimer () => ToolTip(), -ms
}

GuestLog(msg) {
    if Trace.enabled
        TraceWrite("RECEIVER", msg " " TraceModifiers())
}

OnGuestExit(*) {
    GuestReset("çıkış")
}
