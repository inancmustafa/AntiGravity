# SM Kısayol Köprüsü (AHK v2)

VMware Horizon HTML/Blast web client'ı üzerinden bağlanılan sanal makineye (**SM**), host işletim sisteminin yuttuğu sistem kısayollarını (Alt+Tab, Win) iletir.

## Sorun

Tarayıcı, işletim sistemi düzeyindeki kısayolları yakalayamaz. Horizon web client'ında Alt+Tab'a bastığında host PC pencere değiştirir, SM değil.

Chromium tabanlı tarayıcılarda [Keyboard Lock API](https://developer.mozilla.org/en-US/docs/Web/API/Keyboard/lock) ile sayfa bu tuşları tam ekranda yakalayabilir. **Gecko (Firefox/Waterfox) bu API'yi desteklemez.** Dolayısıyla Waterfox kullanıldığında bu köprü opsiyonel bir kolaylık değil, **tek mekanizmadır**.

## Nasıl çalışır

```
  HOST PC                                             SM (sanal makine)
  ───────────────────────────────────                 ──────────────────────────
  Sol Alt basılı tutulur
      │
      ├─ Host_PC_Bridge.ahk tuşu YUTAR
      │  ve yerine F13 down enjekte eder
      │                                    Horizon
      └─ SendEvent {F13 down}  ──────────  protokolü  ──────►  Guest_SM_Receiver.ahk
                                                                    │
  Tab'a basılır                                                     └─ Send {Alt down}
      └─ SendEvent {F14 down/up} ─────────────────────────────►  Send {Tab down/up}
                                                                    │
  Alt bırakılır                                                     │  Windows'un kendi
      └─ SendEvent {F13 up}  ─────────────────────────────────►  Send {Alt up}
                                                                       Alt+Tab overlay'i
```

F13–F24 tuşları seçilmesinin nedeni: fiziksel klavyelerde bulunmazlar, hiçbir uygulama onları kullanmaz, ama uzak masaüstü protokolünden geçebilirler.

**Basılı tutma modeli:** Alt+Tab bir durum makinesidir — overlay Alt basılı kaldıkça açık kalır, Tab'a art arda basılabilir, Alt bırakılınca seçim onaylanır. Bu yüzden Alt/Tab/Shift/Win'in down ve up olayları ayrı ayrı köprülenir.

## Dosyalar

| Dosya | Nerede çalışır | Açıklama |
|---|---|---|
| `Bridge_Config.ahk` | **her iki taraf** | Tek gerçek kaynak: köprü tablosu, pencere kuralı, zamanlama |
| `Host_PC_Bridge.ahk` | host PC | Tuşları yakalar, yutar, köprü tuşlarını enjekte eder |
| `Guest_SM_Receiver.ahk` | SM içinde | Köprü tuşlarını gerçek kısayollara çevirir |
| `Test_BridgeKeys.ahk` | host PC | Test 1: F13–F24'ü tek tek gönderir |
| `Test_ShowKeys.ahk` | SM içinde | Test 1: SM'e ulaşan tuşları listeler |
| `Waterfox_SM/Setup_SM_Profile.ps1` | host PC | SM profilini oluşturur, `user.js`'i yerleştirir |
| `Waterfox_SM/user.js` | → SM profili | Ayrılmış profil için Gecko tercihleri |
| `Waterfox_SM/Start_SM.cmd` | host PC | SM'i kiosk modunda açar |

> `Bridge_Config.ahk` her iki tarafta da gerekir. SM'e `Guest_SM_Receiver.ahk` ile **birlikte, aynı klasöre** kopyala. Eskiden köprü tuşları iki dosyada elle senkron tutulmak zorundaydı; artık tek yerde.

---

## Kurulum

### 1. Host PC

AutoHotkey v2 kurulu olmalı ([autohotkey.com](https://www.autohotkey.com/)).

```powershell
# SM'e ayrılmış Waterfox profilini oluştur ve user.js'i yerleştir
powershell -ExecutionPolicy Bypass -File Waterfox_SM\Setup_SM_Profile.ps1
```

Sonra `Host_PC_Bridge.ahk`'ye çift tıkla. Otomatik başlatmak için kısayolunu `shell:startup` klasörüne koy.

### 2. SM (sanal makine)

SM'in içine AutoHotkey v2 kur, sonra şu **iki** dosyayı aynı klasöre kopyala:

- `Guest_SM_Receiver.ahk`
- `Bridge_Config.ahk`

`Guest_SM_Receiver.ahk`'ye çift tıkla. Otomatik başlatmak için SM içinde `shell:startup` kullan.

> Dosyaları SM'e taşımak için Horizon'un sürücü eşleme özelliğini kullanabilir veya SM içinden indirebilirsin. Kurumsal politika SM'de AHK'yı engelliyorsa IT ile görüş.

### 3. SM penceresini aç

`Waterfox_SM\Start_SM.cmd` — veya host script'inin tray menüsünden **"SM'i Başlat"**.

Açılan komut satırı:

```
waterfox.exe -P "SM" --no-remote --kiosk "https://vgpu-secure.fnss.com.tr/portal/webclient/#/desktop"
```

`--kiosk` sekme ve adres çubuğunu kaldırır, tarayıcı UI kısayollarının çoğunu devre dışı bırakır.

> ⚠ **Kiosk + köprü = Alt+F4 artık Waterfox'u kapatmaz** (Alt SM'e gidiyor). Çıkış için **Ctrl+Alt+Shift+Q**. Kiosk moduna güvenmeden önce bu tuşun çalıştığını doğrula.

---

## Ölçüm — kuruluma başlamadan yapılması gerekenler

Bu iki test tahmin yerine ölçüm koyar. Sonuçları `Bridge_Config.ahk`'yi nasıl dolduracağını belirler.

### Test 1 — hangi köprü tuşları SM'e ulaşıyor?

Bazı uzak masaüstü protokolleri F13 ve üstünü iletmez.

1. SM içinde `Guest_SM_Receiver.ahk`'yi **kapat**, `Test_ShowKeys.ahk`'yi çalıştır.
2. Host'ta `Test_BridgeKeys.ahk`'yi çalıştır. Ekranda tetikleyici tuş listesi çıkar.
3. SM penceresine tıkla, sonra `1`–`9`, `0`, `-`, `=` tuşlarına tek tek bas (veya `F1` ile hepsini tara).
4. SM'deki listede **görünen** tuşları not et.
5. `BRIDGE_TABLE`'da yalnızca ulaşan tuşları kullan. `Esc` ile test scriptini kapat.

### Test 2 — Waterfox hangi kısayolları çalıyor?

Gecko bazı kendi kısayollarını sayfanın `preventDefault`'una bırakmaz; o tuşlar SM'e hiç ulaşmaz. Ama `--kiosk` bunların bir kısmını zaten çözüyor olabilir — bu yüzden **ölçmeden köprülemiyoruz**.

SM oturumu açıkken (alıcı çalışıyor, kiosk modunda) şunları tek tek dene ve hangisinin **Waterfox'a** etki ettiğini, hangisinin **SM'e** ulaştığını not et:

`Ctrl+W` · `Ctrl+T` · `Ctrl+N` · `Ctrl+Shift+W` · `Ctrl+S` · `Ctrl+P` · `Ctrl+F` · `Ctrl+L` · `F11` · `Alt+Sol` · `Backspace`

SM'e ulaşmayan her biri için `Bridge_Config.ahk`'de ilgili satırın yorumunu kaldır. **Hepsini birden açma** — gereksiz köprü, tarayıcıdan geçmesi gereken bir tuşu da yutar.

> **Ctrl bilinçli olarak köprülenmiyor.** Ctrl'ün tamamını köprülemek her Ctrl çakışmasını tek hamlede çözerdi, ama Horizon'un tarayıcı seviyesindeki pano (Ctrl+C / Ctrl+V) senkronizasyonunu bozma riski var. Bu yüzden yalnızca ölçümle kanıtlanan tek tek kombinasyonlar köprülenir.

---

## Desteklenen kısayollar

| Host'ta bastığın | Köprü tuşu | SM'de olan |
|---|---|---|
| **Sol Alt** (basılı tut) | F13 down/up | Alt basılı tutulur → overlay açılır, bırakılınca onaylanır |
| **Tab** (Alt basılıyken) | F14 down/up | Tab → seçim ilerler |
| **Shift** (Alt basılıyken) | F15 down/up | Shift → seçim geri gider (Alt+Shift+Tab) |
| **Win** (sol veya sağ) | F16 down/up | Win basılı tutulur → Başlat menüsü, **ve Win+D / Win+E gibi kombinasyonlar** |
| — | F17 | RESET: SM'deki tüm modifier'ları bırak |

Win tuşu `down/up` olarak köprülendiği için Win+D, Win+E, Win+R gibi kombinasyonlar çalışır: harf tuşu tarayıcıdan normal şekilde geçip SM'e ulaşır ve orada basılı tutulan Win ile birleşir.

## Operasyon hotkey'leri

| Hotkey | Nerede | İşlev |
|---|---|---|
| `Ctrl+Alt+Shift+S` | host | Köprüyü duraklat / devam ettir |
| `Ctrl+Alt+Shift+R` | host | Panik: SM'deki tüm modifier'ları bırak |
| `Ctrl+Alt+Shift+Q` | host | SM penceresini kapat (kiosk modunda tek çıkış) |
| `Ctrl+Alt+Shift+R` | **SM içinde** | Yerel panik: SM'de takılı modifier'ları bırak |

Her iki tarafta tray ikonunun üzerine gelince o anki durum (basılı köprü tuşları, duraklatıldı mı) görünür.

---

## Köprülenmeyenler — bunları "düzeltmeyin"

Bunlar eksik değil, bilinçli kararlar:

### RAlt / AltGr — Alt+Tab yalnızca SOL Alt ile çalışır

Host scripti yalnızca `LAlt`'ı yakalar. Türkçe-Q klavyede AltGr (= sağ Alt) `@ [ ] { }` karakterleri için zorunludur. AltGr köprülenirse Waterfox'a ve SM'e hiç ulaşmaz ve bu karakterler **yazılamaz hale gelir**.

Yani: Alt+Tab için sol Alt'ı kullan. Bu, ödenmesi gereken doğru bedel.

### Win+L

Windows'un sistem düzeyinde ayırdığı bir kısayoldur; AHK onu engelleyemez. Basarsan **host PC kilitlenir**, SM değil. SM'i kilitlemek için Başlat menüsünü (Win) kullan.

### Ctrl+Alt+Del

Windows, Secure Attention Sequence'i enjekte edilen girdiye kapatır — hiçbir script bunu tetikleyemez. **Horizon araç çubuğundaki Ctrl+Alt+Del düğmesini** kullan.

---

## Yeni bir kısayol köprülemek

`Bridge_Config.ahk` içindeki `BRIDGE_TABLE`'a **tek satır** ekle:

```ahk
{ bridge: "F19", host: ["^t"], guest: "^t", mode: "tap", needsAlt: false },
```

| Alan | Anlamı |
|---|---|
| `bridge` | Kullanılacak köprü tuşu. **Test 1 ile SM'e ulaştığını doğrula.** |
| `host` | Host'ta yakalanıp yutulacak tuş(lar). Dizi — `["LWin", "RWin"]` gibi çoklu olabilir. |
| `guest` | SM'de üretilecek şey. `mode: "hold"` ise tuş adı (`"Alt"`), `"tap"` ise Send dizisi (`"^t"`). |
| `mode` | `"hold"` → down/up aynalanır (durum makineleri). `"tap"` → tek vuruş. |
| `needsAlt` | `true` → host'ta yalnızca Alt köprüsü basılıyken yakalanır. |

Değişiklikten sonra **her iki tarafta** scriptleri yeniden başlat (tray → Yeniden Yükle) ve `Bridge_Config.ahk`'nin güncel kopyasını SM'e tekrar kopyala.

---

## Sorun giderme

| Belirti | Bakılacak yer |
|---|---|
| Alt+Tab hiç çalışmıyor | **Test 1**: F13/F14 SM'e ulaşıyor mu? Ulaşmıyorsa `BRIDGE_TABLE`'da ulaşan tuşlara geç. |
| Sağ Alt ile Alt+Tab çalışmıyor | Beklenen davranış — sol Alt kullan (yukarıdaki AltGr bölümü). |
| SM'de Alt takılı kaldı | `Ctrl+Alt+Shift+R` (host veya SM). Watchdog zaten `HOLD_TIMEOUT_MS` (8 sn) sonra kendi bırakır. |
| Alt+Tab bir pencere atlıyor | Ağ jitter'ı: F14, F13'ten önce ulaşmış. `Bridge_Config.ahk`'de `DEBUG_LOG := true` yapıp `%TEMP%\shortcut_bridge.log`'a bak. |
| Overlay açılmıyor, pencere direkt değişiyor | `GUEST_SETTLE_MS`'i 10–30 arası bir değere çıkar. |
| Köprü hiç tetiklenmiyor | SM penceresi `ahk_exe waterfox.exe` ile eşleşiyor mu? AHK Window Spy ile kontrol et. |
| Günlük tarayıcımda Alt+Tab bozuldu | O tarayıcı `SM_WINDOW` kuralına giriyor demektir. Kural yalnızca Waterfox'u kapsamalı. |
| Ctrl+W SM'e ulaşmıyor | **Test 2** → `BRIDGE_TABLE`'daki `^w` satırını aç. |
| Kiosk penceresi kapanmıyor | `Ctrl+Alt+Shift+Q`. Çalışmıyorsa Görev Yöneticisi'nden `waterfox.exe`. |
| Horizon client'ta garip görüntü/ölçek sorunu | SM profilinde `privacy.resistFingerprinting` — `user.js` bunu `false` yapar, uygulandığını doğrula. |

### Teşhis

```powershell
# Sözdizimi kontrolü (çalıştırmadan)
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' /validate /ErrorStdOut Host_PC_Bridge.ahk
```

Ayrıntılı iz için `Bridge_Config.ahk`'de `DEBUG_LOG := true` → `%TEMP%\shortcut_bridge.log` (her iki taraf da aynı dosya adını kullanır, kendi makinesinde).

---

## Geliştirici notları

- **Dosyalar BOM'suz UTF-8 olarak kaydedilmelidir.** AHK v2 script dosyalarını varsayılan olarak UTF-8 okur. Başa BOM eklenirse ilk satırdaki anahtar sözcüğe BOM karakteri yapışır ve AHK onu bambaşka bir tanımlayıcı olarak ayrıştırır — hata mesajı da bunu göstermez, saatler kaybettirir.
- **`global` anahtar sözcüğü kullanılmaz.** Tüm değişken durum tek bir nesnede (`St` host'ta, `G` guest'te) tutulur. Nesne *özelliğine* atama yapmak `global` bildirimi gerektirmediği için fonksiyonların içinde tek bir `global` satırı yok — super-global kapsam belirsizliği tamamen ortadan kalkıyor.
- **`up` olayları geçirmeli (`~`) ve bağlamsız kaydedilir.** Odak SM penceresinden çıksa bile yakalanmaları gerekir, ama Alt-up'ı global olarak yutmak host'ta Alt'ı bozar. Köprüleme sırasında Alt-down zaten yutulduğu için OS'in eşleşmeyen bir Alt-up görmesi zararsızdır.
- **Odak kaybında köprü tuşu gönderilmez.** `SendEvent` o an odakta olan pencereye gider; odak SM'den çıkmışken göndermek hem alakasız bir uygulamaya kaçak tuş enjekte eder hem SM'de modifier'ı takılı bırakır. Onun yerine `pendingReset` işaretlenir ve odak döndüğünde RESET gönderilir.
- **Tab/Shift bağlamı fiziksel tuş durumuna değil köprü durumuna bakar** (`St.held.Has(ALT_BRIDGE)`). Böylece host'un fiziksel durumu ile guest'in inandığı durum ayrışamaz.
