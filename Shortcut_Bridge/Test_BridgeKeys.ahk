#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Bridge_Config.ahk
SetKeyDelay HOST_KEY_DELAY, HOST_KEY_DELAY

; ==============================================================================
; TEST 1 - KÖPRÜ TUŞU TESLİM TESTİ (HOST tarafında çalıştır)
; ==============================================================================
; Hangi köprü tuşlarının (F13-F24) Horizon protokolünden geçip SM'e ULAŞTIĞINI
; ölçer. Bazı uzak masaüstü protokolleri F13 ve üstünü iletmez; hangi tuşların
; kullanılabilir olduğunu ÖNCEDEN bilmek gerekir.
;
; DAVRANIŞ: Tetikleyici tuşu GERÇEK KÖPRÜ GİBİ aynalar — basınca {Fnn down},
; bırakınca {Fnn up}. Auto-repeat guard'ı var, yani tuşu basılı tutmak tek bir
; down üretir, spam yapmaz. (Gerçek köprüdeki Alt davranışının aynısı.)
;
; KULLANIM:
;   1. SM içinde Test_ShowKeys.ahk'yi çalıştır (Guest_SM_Receiver.ahk KAPALI).
;   2. Host'ta bu scripti çalıştır.
;   3. SM penceresine tıkla — odak orada olmalı, yoksa tuşlar Horizon'a girmez.
;   4. Tetikleyicilere tek tek bas. SM'deki listede hangi tuşlar "down" ve "up"
;      olarak göründü?
;   5. Yalnızca ULAŞAN tuşları Bridge_Config.ahk'deki BRIDGE_TABLE'da kullan.
;
; Test bitince kapat (Esc) — tetikleyici tuşları yuttuğu için açık kalmamalı.
; ==============================================================================

BRIDGE_KEYS := ["F13","F14","F15","F16","F17","F18","F19","F20","F21","F22","F23","F24"]
TRIGGERS    := [ "1",  "2",  "3",  "4",  "5",  "6",  "7",  "8",  "9",  "0",  "q",  "w"]

T := { down: Map() }

for i, trigger in TRIGGERS {
    Hotkey "*" trigger,        TriggerDown.Bind(BRIDGE_KEYS[i], trigger)
    Hotkey "*" trigger " up",  TriggerUp.Bind(BRIDGE_KEYS[i], trigger)
}

Hotkey "*F1",  (*) => SweepAll()
Hotkey "*Esc", (*) => ExitApp()

ShowLegend()
return

TriggerDown(bridgeKey, trigger, *) {
    ; Auto-repeat guard — gerçek köprüdeki HoldDown ile aynı mantık.
    ; Bu olmasa tuşu basılı tutmak down/up spam'i üretirdi.
    if T.down.Has(trigger)
        return
    T.down[trigger] := true
    SendEvent "{Blind}{" bridgeKey " down}"
    Show(trigger "  ->  " bridgeKey "  DOWN")
}

TriggerUp(bridgeKey, trigger, *) {
    if !T.down.Has(trigger)
        return
    T.down.Delete(trigger)
    SendEvent "{Blind}{" bridgeKey " up}"
    Show(trigger "  ->  " bridgeKey "  UP")
}

SweepAll() {
    for i, key in BRIDGE_KEYS {
        Show("Tarama " i "/" BRIDGE_KEYS.Length ":  " key)
        SendEvent "{Blind}{" key " down}"
        Sleep 120
        SendEvent "{Blind}{" key " up}"
        Sleep 400
    }
    Show("Tarama bitti — SM'deki listeyi kontrol et", 5000)
}

ShowLegend() {
    legend := "KÖPRÜ TUŞU TESTİ  (host)`n`n"
    for i, key in BRIDGE_KEYS
        legend .= "   " TRIGGERS[i] "  ->  " key "`n"
    legend .= "`n   F1   ->  hepsini sırayla tara`n"
    legend .=   "   Esc  ->  çık`n`n"
    legend .= "Önce SM penceresine tıkla, sonra tuşa bas.`n"
    legend .= "Basılı tutmak spam yapmaz — tek down, bırakınca up."
    Show(legend, 9000)
}

Show(msg, ms := 2500) {
    ToolTip msg, 30, 30
    SetTimer () => ToolTip(), -ms
}
