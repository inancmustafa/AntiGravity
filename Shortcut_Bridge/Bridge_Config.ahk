#Requires AutoHotkey v2.0

; ==============================================================================
; PAYLAŞILAN KÖPRÜ YAPILANDIRMASI
; ==============================================================================
; Host_PC_Bridge.ahk ve Guest_SM_Receiver.ahk bu dosyayı #Include eder.
; TEK GERÇEK KAYNAK: köprü tuşları burada değişir, iki taraf birlikte değişir.
;
; ÖNEMLİ: Bu dosya SM'e (sanal makineye) Guest_SM_Receiver.ahk ile BİRLİKTE
; kopyalanmalıdır. İkisi aynı klasörde olmalı.
;
; NOT: Bu dosya BOM'suz UTF-8 olarak kaydedilmelidir. Başına BOM eklenirse AHK
; ilk satırdaki anahtar sözcüğe BOM karakterini yapıştırır ve script bozulur.
; ==============================================================================

BRIDGE_PROTOCOL_VERSION := 2

; ------------------------------------------------------------------------------
; KÖPRÜ TABLOSU
; ------------------------------------------------------------------------------
;   bridge   : Host'un enjekte ettiği, Horizon protokolünden geçen köprü tuşu.
;   host     : Host'ta yakalanıp YUTULAN gerçek tuş(lar). Dizi — bir köprü tuşuna
;              birden fazla fiziksel tuş bağlanabilir (ör. LWin + RWin).
;   guest    : SM içinde üretilecek tuş. mode="hold" ise tuş ADI ("Alt"),
;              mode="tap" ise Send dizisi ("^w").
;   mode     : "hold" -> down/up aynalanır. Alt+Tab ve Win+D gibi kombinasyonlar
;                        bir durum makinesidir; overlay Alt basılı kaldıkça açık
;                        kalır, bırakılınca seçim onaylanır.
;              "tap"  -> tek vuruş.
;   needsAlt : true ise host'ta YALNIZCA Alt köprüsü basılıyken yakalanır.
;              Kritik: Alt basılı değilken bu hotkey hiç kayıtlı olmadığı için
;              tuş tarayıcıya DOKUNULMADAN geçer. Yoksa SM içinde düz Tab
;              tamamen bozulurdu.
;
; Yeni bir kısayol köprülemek = buraya tek satır eklemek.
; Ama önce Test_BridgeKeys.ahk + Test_ShowKeys.ahk ile o köprü tuşunun SM'e
; gerçekten ULAŞTIĞINI doğrula (README > "Ölçüm").
; ------------------------------------------------------------------------------
BRIDGE_TABLE := [
    ; --- Host OS'in yuttuğu sistem kısayolları -------------------------------
    { bridge: "F13", host: ["LAlt"],          guest: "Alt",   mode: "hold", needsAlt: false },
    { bridge: "F14", host: ["Tab"],           guest: "Tab",   mode: "hold", needsAlt: true  },
    { bridge: "F15", host: ["Shift"],         guest: "Shift", mode: "hold", needsAlt: true  },
    { bridge: "F16", host: ["LWin", "RWin"],  guest: "LWin",  mode: "hold", needsAlt: false },

    ; --- Waterfox'un çaldığı tarayıcı kısayolları ----------------------------
    ; Gecko bazı kendi kısayollarını sayfanın preventDefault'una bırakmaz;
    ; o tuşlar SM'e hiç ulaşmaz. AMA kiosk modu bunların bir kısmını zaten
    ; çözüyor olabilir.
    ;
    ; Bu satırları TOPTAN AÇMA. README > "Test 2" ile hangisinin gerçekten
    ; bozuk olduğunu ölç, yalnızca onu aç. Gereksiz köprü, tarayıcıdan geçmesi
    ; gereken bir tuşu da yutar.
    ; { bridge: "F18", host: ["^w"],    guest: "^w",    mode: "tap", needsAlt: false },
    ; { bridge: "F19", host: ["^t"],    guest: "^t",    mode: "tap", needsAlt: false },
    ; { bridge: "F20", host: ["^n"],    guest: "^n",    mode: "tap", needsAlt: false },
    ; { bridge: "F21", host: ["^s"],    guest: "^s",    mode: "tap", needsAlt: false },
    ; { bridge: "F22", host: ["^p"],    guest: "^p",    mode: "tap", needsAlt: false },
    ; { bridge: "F23", host: ["^+w"],   guest: "^+w",   mode: "tap", needsAlt: false },
    ; { bridge: "F24", host: ["^+Esc"], guest: "^+Esc", mode: "tap", needsAlt: false },
]

; ------------------------------------------------------------------------------
; RESET KÖPRÜ TUŞU
; ------------------------------------------------------------------------------
; Guest bu tuşu alınca TÜM basılı modifier'ları bırakır.
; Host bunu şu durumlarda gönderir: odak kaybı sonrası SM'e dönüşte, suspend'e
; girerken, panik hotkey'inde, script çıkışında.
; (Eskiden bu slot Ctrl+Alt+Del içindi; CAD köprülenmiyor — README'ye bak.)
; ------------------------------------------------------------------------------
BRIDGE_RESET := "F17"

; Alt köprüsünün hangi tuş olduğunu tablodan türet (needsAlt kontrolleri kullanır).
ALT_BRIDGE := ""
for _e in BRIDGE_TABLE
    if (_e.guest = "Alt")
        ALT_BRIDGE := _e.bridge

; ------------------------------------------------------------------------------
; SM PENCERESİ VE TARAYICI (yalnızca host tarafında kullanılır)
; ------------------------------------------------------------------------------
; Waterfox SM'e AYRILMIŞ olduğu için exe eşleştirmesi yeterli ve en sağlamdır:
; SM oturumuna bağlandıktan sonra sayfa başlığı masaüstü havuzu adına dönebilir,
; bu yüzden başlık birincil kural DEĞİL.
;
; Waterfox'u SM dışında da kullanmaya başlarsan üstteki satırı yorumla, alttakini
; aç. (Portal sayfasının başlığı doğrulandı: "VMware Horizon")
SM_WINDOW := "ahk_exe waterfox.exe"
; SM_WINDOW := "VMware Horizon ahk_exe waterfox.exe"

SM_BROWSER_EXE := "C:\Program Files\Waterfox\waterfox.exe"
SM_PROFILE     := "SM"
SM_URL         := "https://vgpu-secure.fnss.com.tr/portal/webclient/#/desktop"

; ------------------------------------------------------------------------------
; ZAMANLAMA VE TEŞHİS
; ------------------------------------------------------------------------------
HOST_KEY_DELAY  := 10     ; Host SendEvent tuş gecikmesi (ms). Horizon canvas'ı JS
                          ; klavye olaylarını okur; SendInput'un sıfır gecikmeli
                          ; patlaması tarayıcı olay döngüsünde düşürülebilir.
GUEST_SETTLE_MS := 0      ; Guest: Alt down sonrası bekleme. Overlay açılmıyorsa
                          ; 10-30 arası dene.
HOLD_TIMEOUT_MS := 8000   ; Guest watchdog: bu süre hareketsizlikte her şeyi bırak.
DEBUG_LOG       := false  ; true -> %TEMP%\shortcut_bridge.log
