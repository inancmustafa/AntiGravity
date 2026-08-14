#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; TEST 1 - KÖPRÜ TUŞU TESLİM TESTİ (HOST tarafında çalıştır)
; ==============================================================================
; Hangi köprü tuşlarının (F13-F24) Horizon protokolünden geçip SM'e ULAŞTIĞINI
; ölçer. Bazı uzak masaüstü protokolleri F13 ve üstünü iletmez; hangi tuşların
; kullanılabilir olduğunu ÖNCEDEN bilmek gerekir.
;
; KULLANIM:
;   1. SM içinde Test_ShowKeys.ahk'yi çalıştır.
;   2. Host'ta bu scripti çalıştır.
;   3. SM penceresine (Waterfox) tıkla, odağın orada olduğundan emin ol.
;   4. Tetikleyici tuşlara tek tek bas. SM'deki listede hangileri göründü?
;   5. Yalnızca ULAŞAN tuşları Bridge_Config.ahk'deki BRIDGE_TABLE'da kullan.
;
; Test bitince bu scripti kapat (Esc) — tetikleyici tuşları yuttuğu için açık
; kalmamalı.
; ==============================================================================

BRIDGE_KEYS := ["F13","F14","F15","F16","F17","F18","F19","F20","F21","F22","F23","F24"]
TRIGGERS    := ["1","2","3","4","5","6","7","8","9","0","-","="]

for i, trigger in TRIGGERS
    Hotkey "*" trigger, FireBridge.Bind(BRIDGE_KEYS[i], trigger)

Hotkey "*F1", (*) => SweepAll()
Hotkey "*Esc", (*) => ExitApp()

ShowLegend()
return

FireBridge(bridgeKey, trigger, *) {
    SendEvent "{" bridgeKey "}"
    Show(trigger " ->  " bridgeKey " gönderildi")
}

SweepAll() {
    for i, key in BRIDGE_KEYS {
        Show("Tarama " i "/" BRIDGE_KEYS.Length ":  " key)
        SendEvent "{" key "}"
        Sleep 500
    }
    Show("Tarama bitti — SM'deki listeyi kontrol et")
}

ShowLegend() {
    legend := "KÖPRÜ TUŞU TESTİ  (host)`n`n"
    for i, key in BRIDGE_KEYS
        legend .= "   " TRIGGERS[i] "  ->  " key "`n"
    legend .= "`n   F1   ->  hepsini sırayla tara`n"
    legend .=   "   Esc  ->  çık`n`n"
    legend .= "Önce SM penceresine tıkla, sonra tuşa bas."
    Show(legend, 8000)
}

Show(msg, ms := 2500) {
    ToolTip msg, 30, 30
    SetTimer () => ToolTip(), -ms
}
