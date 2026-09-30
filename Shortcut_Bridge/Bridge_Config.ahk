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

BRIDGE_PROTOCOL_VERSION := 6

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

    ; Waterfox kısayolları bu tabloyla DEĞİL, aşağıdaki TAŞIMA protokolüyle SM'e
    ; gider (F18-F23). F17 RESET, F24 canlılık sinyalidir. mode "tap" girdileri
    ; hâlâ desteklenir ama boş taşıyıcı tuş kalmadı.
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

; ------------------------------------------------------------------------------
; WATERFOX KISAYOLLARININ SM'E TAŞINMASI
; ------------------------------------------------------------------------------
; SM sekmesinde Waterfox'un hiçbir kısayolu çalışmaz; tuşlar SM'e gider. Bazı
; kısayolları (Ctrl+T/N/W, Ctrl+Shift+W/P/Q, Ctrl+PgUp/PgDn...) tarayıcı sayfaya
; hiç bırakmaz, Horizon da iletemez. Köprü sol Alt'ı ve Win'i yuttuğu için
; Waterfox Ctrl+Alt+T'yi Ctrl+T olarak görür.
;
; Host tuşu yutar ve bir TAŞIYICI DİZİ gönderir: CARRY_START + 3 hane + 1 kontrol
; hanesi (CARRY_DIGITS = 0..4). Guest diziyi çözer ve tuşu {Blind} ile basar;
; Ctrl/Shift doğal yoldan, Alt/Win köprüden zaten basılıdır. Kontrol hanesi
; protokol sürümünü içerir: sürümü farklı host/guest diziyi reddeder.
;
; Taşınanlar (yalnızca SM penceresi + Horizon sekmesi aktifken):
;   * Ctrl (+Shift) ile basılan CARRY_KEYS tuşları (CARRY_NATURAL hariç)
;   * Ctrl+Alt+... ile basılan tüm CARRY_KEYS tuşları
;   * Win basılıyken basılan tüm CARRY_KEYS tuşları (Win+D, Win+E, Win+Sol...)
;   * Modifier'lı ya da modifier'sız F1-F12 (F5 yenileyip oturumu koparmasın,
;     F11 tam ekrandan çıkmasın, F12 geliştirici araçlarını açmasın).
;     İstisna: Ctrl+F11 Waterfox'un tam ekranını aç/kapatır (host'ta kalır).
; Taşınmayanlar: AltGr (sağ Alt) basılıyken -- Türkçe karakterler doğal yoldan;
; kontrol kısayolları Ctrl+Alt+Shift+S/R/Q/M/H -- host'ta kalır.
;
; CARRY_KEYS SIRASI PROTOKOLDÜR: değiştirirsen BRIDGE_PROTOCOL_VERSION'ı artır ve
; iki tarafa birlikte dağıt. En fazla 125 tuş.
; ------------------------------------------------------------------------------
CARRY_START      := "F18"
CARRY_DIGITS     := ["F19", "F20", "F21", "F22", "F23"]
CARRY_TIMEOUT_MS := 1000

; Ctrl ile (Alt/Win olmadan) basıldığında DOĞAL yoldan geçenler. Bunlar Waterfox
; kısayolu değil: Horizon yerel pano ile SM panosunu bu tuşlarla eşitler;
; taşınırsa kopyala/yapıştır bozulabilir. Ctrl+Insert de kopyalamadır.
CARRY_NATURAL := Map("vk43", true, "vk56", true, "vk58", true, "Insert", true)

; Harfler ve rakamlar klavye düzeninden bağımsız olsun diye vk koduyla.
CARRY_KEYS := []
loop 26
    CARRY_KEYS.Push(Format("vk{:02X}", 0x40 + A_Index))      ; A-Z
loop 10
    CARRY_KEYS.Push(Format("vk{:02X}", 0x2F + A_Index))      ; 0-9
for _k in ["vkBA", "vkBB", "vkBC", "vkBD", "vkBE", "vkBF", "vkC0",
           "vkDB", "vkDC", "vkDD", "vkDE", "vkDF", "vkE2"]
    CARRY_KEYS.Push(_k)                                        ; noktalama, ş ğ ü ö ç i
loop 12
    CARRY_KEYS.Push("F" A_Index)                               ; F1-F12
for _k in ["Left", "Right", "Up", "Down", "Home", "End", "PgUp", "PgDn",
           "Insert", "Delete", "Backspace", "Enter", "Space", "Escape"]
    CARRY_KEYS.Push(_k)
CARRY_INDEX := Map()
for _i, _k in CARRY_KEYS
    CARRY_INDEX[_k] := _i - 1

; Host: tuş -> "{F18}{Fa}{Fb}{Fc}{Fkontrol}"
CarrySequence(key) {
    idx := CARRY_INDEX[key]
    digits := [idx // 25, Mod(idx // 5, 5), Mod(idx, 5)]
    digits.Push(Mod(digits[1] + digits[2] + digits[3] + BRIDGE_PROTOCOL_VERSION, 5))
    seq := "{" CARRY_START "}"
    for d in digits
        seq .= "{" CARRY_DIGITS[d + 1] "}"
    return seq
}

; Guest: 4 hane (0..4) -> tuş adı; bozuk/sürümü farklı dizi -> ""
CarryDecode(digits) {
    if (digits.Length != 4
        || Mod(digits[1] + digits[2] + digits[3] + BRIDGE_PROTOCOL_VERSION, 5) != digits[4])
        return ""
    idx := digits[1] * 25 + digits[2] * 5 + digits[3]
    return idx < CARRY_KEYS.Length ? CARRY_KEYS[idx + 1] : ""
}

; Alt köprüsünün hangi tuş olduğunu tablodan türet (gate koşulları kullanır).
ALT_BRIDGE := ""
WIN_BRIDGE := ""
for _e in BRIDGE_TABLE {
    if (_e.guest = "Alt")
        ALT_BRIDGE := _e.bridge
    if (_e.guest = "LWin")
        WIN_BRIDGE := _e.bridge
}

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

; SEKME KONTROLÜ: Waterfox'un pencere başlığı AKTİF SEKMENİN başlığıdır. Köprü
; yalnızca başlık bu metni içerdiğinde çalışır (büyük/küçük harf duyarsız).
; Böylece aynı pencerede başka bir sekmeye geçince Alt+Tab/Ctrl+Tab/Win yutulmaz.
; Horizon sekmesi "VMware Horizon" başlığını taşır; Omnissa sürümlerinde
; "Omnissa Horizon" olabilir. Bağlı oturumda başlık farklıysa burayı düzelt;
; boş bırakırsan ("") sekme kontrolü kapanır ve pencerenin tamamı köprülenir.
; Adres çubuğuna odaklanmayı ayırt edemez; o durumda köprüyü duraklat.
SM_TITLE_MATCH := "Horizon"

; Ctrl+Alt+Shift+M ile yalnızca bu tarayıcı süreçlerinin pencereleri bağlanabilir.
; Yanlış pencere (ör. editör) işaretlenip orada Alt+Tab/Win'in yutulması engellenir.
SM_ALLOWED_EXES := ["waterfox.exe", "firefox.exe"]

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
GUEST_WIN_TAP_FIX := true ; Guest: tek Win basışında Başlat menüsünü aç. Köprüde Win
                          ; bırakılmadan önce F16-up olayı araya girdiği için Windows
                          ; bunu "tek Win" saymaz (ölçüldü). Başka tuşa basılmadıysa
                          ; alıcı temiz bir Win vuruşu ekler. Başlat açılıp hemen
                          ; kapanıyorsa false yap.
DEBUG_LOG       := false  ; true -> %TEMP%\ShortcutBridgeLogs (veya Diag_*.ahk kullan)

; Hatalı/çakışan protokol tanımlarını başlatmadan yakala.
ValidateBridgeConfig()

SMTitleMatches(title) {
    return SM_TITLE_MATCH = "" || InStr(title, SM_TITLE_MATCH)
}

IsAllowedSMExe(exe) {
    for allowed in SM_ALLOWED_EXES
        if (exe = allowed)
            return true
    return false
}

ValidateBridgeConfig() {
    used := Map(BRIDGE_RESET, true, BRIDGE_KEEPALIVE, true)
    hosts := Map()
    if (BRIDGE_RESET = BRIDGE_KEEPALIVE || KEEPALIVE_MS <= 0
        || HOLD_TIMEOUT_MS <= KEEPALIVE_MS * 2)
        throw Error("Gecersiz RESET/KEEPALIVE veya zamanlama")
    SplitPath SM_BROWSER_EXE, &browserName
    if !IsAllowedSMExe(browserName)
        throw Error("SM_BROWSER_EXE, SM_ALLOWED_EXES icinde degil: " browserName)
    if (CARRY_DIGITS.Length != 5 || CARRY_KEYS.Length > 125 || CARRY_INDEX.Count != CARRY_KEYS.Length)
        throw Error("Gecersiz tasima tanimi (5 hane, en fazla 125 benzersiz tus)")
    for carrier in [CARRY_START, CARRY_DIGITS*] {
        if used.Has(carrier)
            throw Error("Tasiyici tus cakismasi: " carrier)
        used[carrier] := true
    }
    for e in BRIDGE_TABLE {
        if used.Has(e.bridge)
            throw Error("Kopru tusu cakismasi: " e.bridge)
        used[e.bridge] := true
        if (e.mode != "hold" && e.mode != "tap")
            throw Error("Gecersiz mode: " e.mode)
        if (e.gate != "" && e.gate != "alt" && e.gate != "mod")
            throw Error("Gecersiz gate: " e.gate)
        for hostKey in e.host {
            if hosts.Has(hostKey) || CARRY_INDEX.Has(hostKey)
                throw Error("Tekrarlanan host tusu: " hostKey)
            hosts[hostKey] := true
        }
    }
}
