#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; TEST 1 - GELEN TUŞ GÖSTERİCİ (SM içinde çalıştır)
; ==============================================================================
; SM'e ULAŞAN köprü tuşlarını (F13-F24) ekranda listeler.
;
; Neden keyjs.dev / keycode.info değil: o siteler tuşun TARAYICIYA ulaştığını
; gösterir. Bizim ölçmek istediğimiz, tuşun guest İŞLETİM SİSTEMİNE ulaşıp
; ulaşmadığı — köprü orada çalışıyor. Ayrıca bu script internet erişimi veya
; kurumsal politika izni gerektirmez.
;
; KULLANIM:
;   1. Bu scripti SM içinde çalıştır (Guest_SM_Receiver.ahk'yi KAPAT — yoksa
;      aynı tuşları o da yakalar ve gerçek Alt/Tab üretir).
;   2. Host'ta Test_BridgeKeys.ahk ile tuşları gönder.
;   3. Listede görünen tuşlar SM'e ulaşıyor demektir.
;
; Çıkış: Ctrl+Alt+Shift+X
; ==============================================================================

MAX_LINES := 16

L := { lines: [] }

loop 12 {
    key := "F" (12 + A_Index)                 ; F13 .. F24
    ; ~ (geçirmeli): tuşu yutmayız, yalnızca gözlemleriz.
    Hotkey "~*" key,       LogKey.Bind(key, "down")
    Hotkey "~*" key " up", LogKey.Bind(key, "up")
}

Hotkey "^!+x", (*) => ExitApp()

Render("Bekleniyor…  Host'tan köprü tuşu gönder.")
return

LogKey(key, event, *) {
    L.lines.Push(FormatTime(, "HH:mm:ss") "   " key "  " event)
    while (L.lines.Length > MAX_LINES)
        L.lines.RemoveAt(1)
    body := ""
    for line in L.lines
        body .= line "`n"
    Render(body)
}

Render(body) {
    ToolTip "SM'E ULAŞAN TUŞLAR   (çıkış: Ctrl+Alt+Shift+X)`n"
          . "--------------------------------------------`n"
          . body
          , 30, 30
}
