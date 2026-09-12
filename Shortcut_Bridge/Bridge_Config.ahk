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
; Dosyalar UTF-8 olarak kaydedilir. AHK v2 UTF-8 BOM ile de okuyabilir.
; ==============================================================================

BRIDGE_PROTOCOL_VERSION := 4

; ------------------------------------------------------------------------------
; TEMEL İLKE: MODIFIER'LAR ZATEN İLETİLİYOR
; ------------------------------------------------------------------------------
; Ölçümle doğrulandı: Ctrl, Shift ve Alt tek başlarına SM'e sorunsuz iletiliyor.
; Ctrl+harf, Alt+harf de çalışıyor. Bozuk olan yalnızca Alt+Tab ve Ctrl+Tab —
; çünkü Alt+Tab'ı host OS, Ctrl+Tab'ı Waterfox yutuyor.
;
; Sonuç: köprülenmesi gereken şey modifier değil, TAB VURUŞU.
;
; Bu yüzden guest tarafı her zaman {Blind} ile gönderir:
;   {Blind} = "mevcut modifier durumuna dokunma, tuşu olduğu gibi bas"
; Böylece guest hangi modifier'ın basılı olduğunu BİLMEK ZORUNDA DEĞİL:
;   * Alt+Tab   -> guest'te Alt basılı (F13 köprüsüyle)   -> {Blind}{Tab} = Alt+Tab
;   * Ctrl+Tab  -> guest'te Ctrl basılı (doğal iletimle)  -> {Blind}{Tab} = Ctrl+Tab
;   * Ctrl+Shift+Tab -> Ctrl ve Shift ikisi de doğal iletimle -> bedava çalışır
;
; TEK köprü tuşu (F14) üçünü de çözer.
;
; Blind olmasa AHK, Tab'ı "yalnız Tab" yapmak için basılı modifier'ları bırakıp
; geri basardı; bu SM'e sahte modifier-up gönderip kombinasyonu bozardı.
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; KÖPRÜ TABLOSU
; ------------------------------------------------------------------------------
;   bridge : Host'un enjekte ettiği, Horizon protokolünden geçen köprü tuşu.
;   host   : Host'ta yakalanıp YUTULAN gerçek tuş(lar). Dizi — bir köprü tuşuna
;            birden fazla fiziksel tuş bağlanabilir (ör. LWin + RWin).
;   guest  : SM'de üretilecek tuş adı. Guest tarafı bunu {Blind} ile sarar.
;   mode   : "hold" -> down/up aynalanır. Alt+Tab ve Ctrl+Tab gibi kombinasyonlar
;                     durum makinesidir; overlay modifier basılı kaldıkça açık
;                     kalır, bırakılınca seçim onaylanır.
;            "tap"  -> tek vuruş.
;   gate   : Host'ta hangi koşulda yakalanacağı.
;            ""     -> SM penceresi aktifse
;            "alt"  -> SM aktif VE Alt köprüsü basılı
;            "mod"  -> SM aktif VE (Alt köprüsü basılı VEYA Ctrl fiziksel basılı)
;
; KRİTİK — `gate` neden var:
; Tab için host'ta YALNIZCA TEK bir hotkey (`*Tab`) kayıtlı olmalı. Daha önce
; Alt+Tab için `*Tab` ve Ctrl+Tab için `^Tab` ayrı ayrı kayıtlıydı; AHK Ctrl+Tab
; basıldığında ikisi arasında seçim yapmak zorunda kaldı, wildcard olan `*Tab`
; öne geçti, varyantı pasif olduğu için tuş hiç yakalanmadan geçti ve `^Tab`
; sıraya bile gelmedi. `gate: "mod"` iki durumu TEK hotkey'de birleştirir.
;
; Yeni bir kısayol köprülemek = buraya tek satır eklemek.
; Ama önce Test_BridgeKeys.ahk + Test_ShowKeys.ahk ile o köprü tuşunun SM'e
; gerçekten ULAŞTIĞINI doğrula (README > "Ölçüm").
; ------------------------------------------------------------------------------
BRIDGE_TABLE := [
    { bridge: "F13", host: ["LAlt"],         guest: "Alt",   mode: "hold", gate: ""    },
    { bridge: "F14", host: ["Tab"],          guest: "Tab",   mode: "hold", gate: "mod" },
    { bridge: "F15", host: ["LShift", "RShift"],        guest: "Shift", mode: "hold", gate: "alt" },
    { bridge: "F16", host: ["LWin", "RWin"], guest: "LWin",  mode: "hold", gate: ""    },

    ; --- Waterfox'un çaldığı diğer kısayollar ---------------------------------
    ; Gecko bazı kendi kısayollarını sayfanın preventDefault'una bırakmaz.
    ; Bunları TOPTAN AÇMA. README > "Test 2" ile hangisinin gerçekten bozuk
    ; olduğunu ölç, yalnızca onu aç. Gereksiz köprü, tarayıcıdan geçmesi
    ; gereken bir tuşu da yutar. (F17 RESET; F18-F23 boş; F24 canlılık sinyali, hepsi test edildi ve
    ; SM'e ulaşıyor.)
    ;
    ; Aynı ilke: Ctrl doğal olarak iletildiği için yalnızca TEMEL TUŞU köprüle.
    ; mode "tap" girdilerinde `host` dizesi OLDUĞU GİBİ kaydedilir, başına `*`
    ; EKLENMEZ — modifier'ları tam yaz.
    ; { bridge: "F18", host: ["^w"],    guest: "w",    mode: "tap", gate: "" },
    ; { bridge: "F19", host: ["^t"],    guest: "t",    mode: "tap", gate: "" },
    ; { bridge: "F20", host: ["^n"],    guest: "n",    mode: "tap", gate: "" },
    ; { bridge: "F21", host: ["^s"],    guest: "s",    mode: "tap", gate: "" },
    ; { bridge: "F22", host: ["^p"],    guest: "p",    mode: "tap", gate: "" },
    ; { bridge: "F23", host: ["^PgDn"], guest: "PgDn", mode: "tap", gate: "" },
    ; F24 canlilik sinyali icin ayrilmistir; kisayol olarak kullanma.
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
BRIDGE_KEEPALIVE := "F24"
KEEPALIVE_MS := 1000

; Alt köprüsünün hangi tuş olduğunu tablodan türet (gate koşulları kullanır).
ALT_BRIDGE := ""
for _e in BRIDGE_TABLE
    if (_e.guest = "Alt")
        ALT_BRIDGE := _e.bridge

; ------------------------------------------------------------------------------
; SM PENCERESİ VE TARAYICI (yalnızca host tarafında kullanılır)
; ------------------------------------------------------------------------------
; PENCERE EŞLEŞTİRME NEDEN HWND TABANLI:
; Waterfox tek profille (mevcut giriş yapılmış hesabınla) kullanılıyor. Bu yüzden
; "köprü penceresi" ile "kendim açtığım normal pencere" birbirinden `ahk_exe
; waterfox.exe` kuralıyla AYIRT EDİLEMEZ — aynı exe, aynı süreç, çoğu zaman aynı
; başlık. Exe eşleştirmesi kullanılsa, kendi açtığın pencerede de Alt+Tab
; yutulurdu.
;
; Çözüm: SM_Baslat.bat ile başlatıldığında köprü Waterfox penceresini KENDİSİ
; açar ve o pencerenin HWND'sini hatırlar. Yalnızca O pencere köprülenir; elle
; açtığın diğer Waterfox pencerelerine hiç dokunulmaz.
;
; Elle açtığın bir pencereyi sonradan köprüye bağlamak istersen: Ctrl+Alt+Shift+M
; (o an aktif olan pencereyi SM penceresi olarak işaretler).
; ------------------------------------------------------------------------------
SM_BROWSER_EXE := "C:\Program Files\Waterfox\waterfox.exe"
SM_URL         := "https://vgpu-secure.fnss.com.tr/portal/webclient/#/desktop"

; Köprü penceresi açıldıktan sonra tam ekrana (F11) geçsin mi?
; Not: yalnızca SM_Baslat.bat ile açılan pencereyi etkiler. Waterfox'u kendin
; açtığında tam ekran olmaz ve köprü de çalışmaz.
SM_FULLSCREEN := true

SM_LAUNCH_TIMEOUT_MS   := 15000   ; yeni Waterfox penceresi ne kadar beklenecek
SM_FULLSCREEN_DELAY_MS := 1200    ; F11 göndermeden önce pencerenin oturması

; ------------------------------------------------------------------------------
; ZAMANLAMA VE TEŞHİS
; ------------------------------------------------------------------------------
HOST_KEY_DELAY  := 10     ; Host SendEvent tuş gecikmesi (ms). Horizon canvas'ı JS
                          ; klavye olaylarını okur; SendInput'un sıfır gecikmeli
                          ; patlaması tarayıcı olay döngüsünde düşürülebilir.
GUEST_SETTLE_MS := 0      ; Guest: Alt down sonrası bekleme. Overlay açılmıyorsa
                          ; 10-30 arası dene.
HOLD_TIMEOUT_MS := 8000   ; Guest watchdog: bu süre hareketsizlikte her şeyi bırak.
DEBUG_LOG       := false  ; true -> %TEMP%\ShortcutBridgeLogs (veya Diag_*.ahk kullan)

; Hatalı/çakışan protokol tanımlarını başlatmadan yakala.
ValidateBridgeConfig()

ValidateBridgeConfig() {
    used := Map(BRIDGE_RESET, true, BRIDGE_KEEPALIVE, true)
    hosts := Map()
    if (BRIDGE_RESET = BRIDGE_KEEPALIVE || KEEPALIVE_MS <= 0
        || HOLD_TIMEOUT_MS <= KEEPALIVE_MS * 2)
        throw Error("Gecersiz RESET/KEEPALIVE veya zamanlama")
    for e in BRIDGE_TABLE {
        if used.Has(e.bridge)
            throw Error("Kopru tusu cakismasi: " e.bridge)
        used[e.bridge] := true
        if (e.mode != "hold" && e.mode != "tap")
            throw Error("Gecersiz mode: " e.mode)
        if (e.gate != "" && e.gate != "alt" && e.gate != "mod")
            throw Error("Gecersiz gate: " e.gate)
        for hostKey in e.host {
            if hosts.Has(hostKey)
                throw Error("Tekrarlanan host tusu: " hostKey)
            hosts[hostKey] := true
        }
    }
}
