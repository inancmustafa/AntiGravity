#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; GELEN TUŞ GÖSTERİCİ (SM içinde çalıştır)
; ==============================================================================
; SM'e ULAŞAN köprü tuşlarını (F13-F24) VE modifier'ları (Ctrl/Shift/Alt/Win)
; ekranda listeler. Her satırda tuşun yanında O ANDA BASILI olan modifier'lar
; da yazar — Ctrl+Tab teşhisi için kritik olan bilgi bu.
;
; Neden keyjs.dev / keycode.info değil: o siteler tuşun TARAYICIYA ulaştığını
; gösterir. Bizim ölçmek istediğimiz, tuşun guest İŞLETİM SİSTEMİNE ulaşıp
; ulaşmadığı — köprü orada çalışıyor. Ayrıca bu script internet erişimi veya
; kurumsal politika izni gerektirmez.
;
; ------------------------------------------------------------------------------
; KULLANIM
; ------------------------------------------------------------------------------
;   1. Guest_SM_Receiver.ahk'yi KAPAT — yoksa aynı tuşları o da yakalar ve
;      gerçek Alt/Tab üretir, ölçüm bozulur.
;   2. Bu scripti SM içinde çalıştır.
;   3. Host'tan tuş gönder (Test_BridgeKeys.ahk veya Diag_CtrlTab.ahk).
;
; NE ARIYORUZ (Ctrl+Tab teşhisi)
;   "F14 down   [Ctrl]"        -> Ctrl SM'e iletiliyor. {Blind}{Tab} çalışmalı;
;                                 sorun guest config'inde (F14 girdisi var mı?).
;   "F14 down   [-]"           -> Horizon çıplak Ctrl'ü İLETMİYOR. Bu durumda
;                                 Ctrl'ü de köprülemek gerekir.
;   Hiç "F14" yok              -> Host tarafı F14 göndermiyor. Diag_CtrlTab.ahk
;                                 ile host'a bak.
;
; Modifier satırları (Ctrl down/up) çıplak Ctrl'ün iletildiğini ayrıca gösterir.
;
; Çıkış: Ctrl+Alt+Shift+X
; ==============================================================================

MAX_LINES := 18

L := { lines: [] }

; --- Köprü tuşları: F13 .. F24 ------------------------------------------------
loop 12 {
    key := "F" (12 + A_Index)
    ; ~ (geçirmeli): tuşu yutmayız, yalnızca gözlemleriz.
    Hotkey "~*" key,       LogKey.Bind(key, "down")
    Hotkey "~*" key " up", LogKey.Bind(key, "up")
}

; --- Modifier'lar: SM'e iletiliyorlar mı? -------------------------------------
; NOT: döngü değişkeni `mod` OLAMAZ — Mod() AHK v2'de yerleşik bir fonksiyon.
for modKey in ["LCtrl", "RCtrl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"] {
    Hotkey "~*" modKey,       LogKey.Bind(modKey, "down")
    Hotkey "~*" modKey " up", LogKey.Bind(modKey, "up")
}

Hotkey "^!+x", (*) => ExitApp()

Render("Bekleniyor…  Host'tan tuş gönder.")
return

LogKey(key, event, *) {
    ; O anda basılı olan modifier'lar — Ctrl+Tab teşhisinin can alıcı verisi.
    mods := ""
    for m in ["Ctrl", "Shift", "Alt", "LWin"]
        if GetKeyState(m)
            mods .= (mods = "" ? "" : "+") m

    L.lines.Push(Format("{1}  {2,-8} {3,-5} [{4}]"
                      , A_TickCount, key, event, (mods = "" ? "-" : mods)))
    while (L.lines.Length > MAX_LINES)
        L.lines.RemoveAt(1)

    body := ""
    for line in L.lines
        body .= line "`n"
    Render(body)
}

Render(body) {
    ToolTip "SM'E ULASAN TUSLAR   (cikis: Ctrl+Alt+Shift+X)`n"
          . "------------------------------------------------`n"
          . body
          , 30, 30
}
