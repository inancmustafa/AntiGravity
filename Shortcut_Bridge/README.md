# SM Kısayol Köprüsü — AutoHotkey v2

Günlük kullanım için **[logger'sız ZIP paketini](releases/Shortcut_Bridge_v6_loggersiz.zip)** indir.
[Kurulum ve bilinen durumlar](RELEASE_README.md). Depodaki teşhis kaynakları
korunur; ZIP yalnızca günlük kullanım dosyalarını içerir.

Waterfox içindeki Horizon HTML/Blast oturumunda yerel Windows veya tarayıcı
tarafından işlenen kısayolları sanal makineye (SM) taşır.

Önceki test notlarına göre Ctrl, Shift ve Alt tek başına SM'e ulaşıyor;
Alt+Tab ve Ctrl+Tab kombinasyonları ise yerelde işleniyordu. Bu gözlem
tarayıcı, Horizon veya ortam değiştiğinde yeniden doğrulanmalıdır.

## Neden tarayıcı tek başına yetmiyor

Chromium'da Horizon tam ekranda `navigator.keyboard.lock()` ile Alt+Tab ve
Win'i yakalayabilir. Waterfox 6.7.2 (Gecko 153) bu API'yi sunmuyor. Onun yerine
`requestFullscreen({keyboardLock})` seçeneği var; ama bu seçenek yalnızca
`"none"` ve `"browser"` değerlerini kabul ediyor, `"system"` geçersiz
(30.09.2026'da ölçüldü). Yani Gecko en fazla tarayıcı kısayollarını
kilitleyebilir; Alt+Tab ve Win işletim sisteminde kalır. Horizon bu seçeneği
zaten istemediği için `dom.fullscreen.keyboard_lock.enabled` ayarını açmak bir
şey değiştirmez. Horizon'un yerel istemcisi de kurum tarafından desteklenmiyor.

Waterfox güncellendiğinde yeniden kontrol et:

```powershell
python tools\probe_keyboard_lock.py
```

Geçici bir profille headless açılır; günlük profile, Horizon'a veya klavyeye
dokunmaz. "system" geçerli olursa köprü duraklatılmış halde canlı oturumda dene.

## Kurulum ve kullanım

1. Host PC ve SM'de AutoHotkey v2 kurulu olmalı.
2. Host'ta bu klasörü tut. `Bridge_Config.ahk` içindeki Waterfox yolu ve
   `SM_URL` ortamına uygun olmalı.
3. SM'e **`Guest_SM_Receiver.ahk`, `Bridge_Config.ahk` ve `Bridge_Logger.ahk` dosyalarını birlikte**
   aynı klasöre kopyala; alıcıyı çalıştır. Alıcının tray menüsünden
   **Oturum açılışında başlat**'ı işaretlersen sonraki oturumlarda kendiliğinden
   açılır. AutoHotkey UI Access bileşeniyle kuruluysa (`AutoHotkey64_UIA.exe`)
   kısayol onu kullanır; alıcı yönetici pencerelerinde de çalışır.
4. Host'ta `SM_Baslat.bat` dosyasını çalıştır. Köprü yeni bir Waterfox
   penceresi açar, o pencerenin HWND'sini tutar ve F11 ile tam ekrana geçer.
5. Horizon masaüstüne bağlan ve uzak masaüstü alanına tıkla.
6. Her iki tray ipucunda **v6** görünmeli. Bu gösterge otomatik sürüm
   uzlaşması değildir; iki tarafta aynı yapılandırma dosyası kullanılmalıdır.

Köprü yalnızca işaretlenmiş Waterfox **penceresinde** ve aktif sekmenin başlığı
`SM_TITLE_MATCH` (varsayılan `Horizon`) metnini içerdiğinde çalışır. Aynı
pencerede başka bir sekmeye geçince Alt+Tab, Ctrl+Tab ve Win host'ta normal
çalışır; tray ipucu "bekliyor: sekme 'Horizon' değil" gösterir. Horizon giriş
ekranının başlığı da "VMware Horizon" olduğu için köprü orada da açıktır.
Adres çubuğu odağını ayırt edemez; orada çalışacaksan köprüyü duraklat.
Bağlı oturumda tray "aktif" demiyorsa (Alt+Tab host'a gidiyorsa) sekme başlığı
eşleşmiyordur: `SM_TITLE_MATCH` değerini düzelt veya `""` yaparak kontrolü kapat.

Elle açılmış bir pencereyi bağlamak için o pencereyi öne getir ve
Ctrl+Alt+Shift+M kullan. Yalnızca `SM_ALLOWED_EXES` içindeki tarayıcılar
(Waterfox, Firefox) bağlanabilir; başka pencereler reddedilir.

İsteğe bağlı profil ayarları:
```powershell
powershell -ExecutionPolicy Bypass -File Waterfox_SM\Apply_Waterfox_Prefs.ps1
```
Bu işlem mevcut profile anasayfa/Alt menüsü/tam ekran tercihlerini yazar;
köprünün çalışması için zorunlu değildir. Mevcut user.js ilk uygulamada
user.js.bak olarak korunur; sonraki uygulama bu yedeği ezmez.
`-Remove` mevcut yedeği geri yükler, yedek yoksa köprü user.js dosyasını
kaldırır. Daha önce prefs.js'e işlenmiş değerler otomatik geri alınmaz.
Birden fazla Waterfox kurulumu/profili varsa yazdırılan hedef dizini kontrol et;
script profiles.ini içindeki ilk Install kaydını veya varsayılan profili seçer.

## Tuşların izlediği yol

```text
Fiziksel klavye
  -> Host_PC_Bridge.ahk
  -> F13/F14/F15/F16 basma-bırakma olayları
  -> Waterfox -> Horizon -> SM
  -> Guest_SM_Receiver.ahk
  -> gerçek Alt/Tab/Shift/Win basma-bırakma olayları
```

| Host girdisi | Taşıyıcı | SM'deki karşılığı |
|---|---|---|
| Sol Alt | F13 down/up | Alt down/up |
| Alt veya Ctrl ile Tab | F14 down/up | Tab down/up |
| Alt köprülenirken sol/sağ Shift | F15 down/up | Shift down/up |
| Sol/sağ Win | F16 down/up | LWin down/up |
| Sıfırlama | F17 | Köprünün tuttuğu tuşları bırakır |
| Waterfox kısayolu (aşağıya bak) | F18 + F19–F23 dizisi | Aynı tuş, SM'de |
| Canlılık sinyali | F24 | Alıcının zaman aşımını yeniler |

Ctrl doğrudan iletilir. Ctrl+Tab ve Ctrl+Shift+Tab için yalnızca Tab köprülenir.
Shift, Alt köprüsü aktif değilken doğrudan iletilir.
Sağ Alt/AltGr köprülenmez; Türkçe klavye karakterleri korunmalıdır.
Alt+Tab için sol Alt kullan.

Host ve guest gönderimleri `{Blind}` kullanır: doğal olarak iletilen
Ctrl/Shift'in gönderim sırasında otomatik bırakılmasını önler.
Sol/sağ Win veya Shift birlikte tutulduğunda köprü son kaynak tuş
bırakılana kadar açık kalır. Basılı tuşun otomatik tekrarları bastırılır;
tekrar seçim için Tab'a yeniden basıp bırakılır.

Alt+Tab seçicisi Alt tutuldukça açık kalmalı, Alt bırakılınca seçim
onaylanmalıdır. Win+D/E/R gibi kombinasyonlarda harf normal kanaldan geçer.

Tek Win basışı SM'de Başlat menüsünü açar. Köprüde Win bırakılırken F16-up
olayı Win down ile Win up arasına girdiği için Windows bunu "tek Win" saymaz
(host üzerinde ölçüldü). Win basılıyken başka tuş gelmediyse alıcı, bıraktıktan
sonra temiz bir Win vuruşu ekler; Win+D gibi kombinasyonlarda eklemez.
Başlat açılıp hemen kapanıyorsa `GUEST_WIN_TAP_FIX := false` yap.

## Waterfox kısayolları SM'e gider

SM penceresinde, Horizon sekmesi aktifken Waterfox'un **hiçbir kısayolu
çalışmaz**; tuşlar SM'e gider. Waterfox bazı kısayolları sayfaya hiç bırakmaz
(Ctrl+T/N/W, Ctrl+Shift+T/W/P/Q, Ctrl+PgUp/PgDn...), Horizon da bunları
iletemez. Köprü sol Alt'ı ve Win'i yuttuğu için Waterfox Ctrl+Alt+T'yi Ctrl+T,
Ctrl+Alt+C'yi Ctrl+C olarak görüyordu.

Host tuşu yutar ve bir taşıyıcı dizi gönderir: F18 + üç hane + bir kontrol
hanesi (F19–F23). Alıcı diziyi çözer ve aynı tuşu SM'de basar; Ctrl/Shift
doğal yoldan, Alt/Win köprüden zaten basılıdır. Kontrol hanesi protokol
sürümünü içerir: host ve SM farklı sürümdeyse dizi reddedilir ve alıcı uyarı
gösterir. Tuş listesi ve kurallar `Bridge_Config.ahk` > TAŞIMA bölümündedir.

| Ne basılırsa | Nereye gider |
|---|---|
| Ctrl+harf/rakam/ok/F-tuşu... (Ctrl+Shift dahil) | SM |
| Ctrl+Alt+... (ör. Ctrl+Alt+T, Ctrl+Alt+C) | SM |
| Win+... (ör. Win+D, Win+E, Win+Sol, Win+Tab) | SM, tuş SM içinde üretilir |
| F1–F12 (F5, F11, F12 dahil) | SM |
| **Ctrl+F11** | Waterfox tam ekranını aç/kapat (Waterfox'ta kalan tek kısayol) |
| **Ctrl+C, Ctrl+V, Ctrl+X, Ctrl+Insert** | Doğal yol (Horizon pano eşitlemesi için) |
| AltGr ile Türkçe karakterler | Doğal yol |
| Ctrl+Alt+Shift+S/R/Q/M/H | Host (köprü kontrolleri) |

Ctrl+C/V/X Waterfox kısayolu değildir; Horizon yerel pano ile SM panosunu bu
tuşlarla eşitler. Taşınırsa kopyala-yapıştır bozulabilir. Yine de taşımak
istersen `CARRY_NATURAL` listesini boşalt.

Win+D daha önce SM'e ulaşmıyordu: Win köprüden, D ise Horizon'dan ayrı ayrı
geliyordu. Artık Win basılıyken basılan tuş da alıcı tarafından SM içinde
üretiliyor.

F11 SM'e gider; SM sekmesinde Waterfox'un tam ekranını **Ctrl+F11** açıp
kapatır (köprü duraklatılmışken de). F6 ile üst paneli açmak yalnızca SM
sekmesi dışında çalışır.

Kontrol kısayolları taşınan tuşlarla aynı hotkey'in öncelikli varyantıdır;
aynı tuşa iki ayrı hotkey kaydedilmez (AHK'nın hangisini seçeceği belgelenmemiş).

## Odak kaybı ve takılı tuşlar

- Host, odağın ayrıldığını 100 ms aralıkla kontrol eder; tutulmuş köprü
  durumunu temizler ve RESET'i dönüşe erteler. Odak dışına taşıyıcı göndermez.
- RESET beklerken yeni köprü down olayları kabul edilmez. Dönüşte F17
  gönderildikten sonra köprü yeniden hazırdır.
- Host, tuş tutulduğu sürece saniyede bir F24 yollar. Böylece uzun Alt
  tutuşları, bağlantı sağlıklıyken 8 saniye sonunda kesilmez. İlk sinyal
  tutuşun 1. saniyesinde gider; kısa vuruşlar sinyalsiz kalır.
- Fiziksel olarak bırakılmış ama up olayı kaçmış kaynaklar host'ta uzlaştırılır.
- Alıcı 8 saniye boyunca köprü olayı/canlılık sinyali almazsa tuttuğu
  tuşları bırakır (watchdog kontrol aralığı 1 saniyedir).
- Normal RESET ve watchdog yalnızca köprünün izlediği tuşları bırakır.
  Doğal Ctrl/AltGr'yi zorla bırakmak için **SM içindeki** yerel panik veya
  alıcı tray menüsü kullanılır.

Odak değiştirdikten veya bağlantı koptuktan sonra kombinasyon tuşlarını
bırakıp yeniden bas. Bu protokol bağlantı onayı veya kayıp paket yeniden
iletimi içermez; F24 yalnızca canlılık sinyalidir. Tarayıcı/Horizon olay
kaybı ya da uzak oturum odağı sorunları uçtan uca ölçülmelidir.

## Kontrol kısayolları

| Tuş | Host işlemi |
|---|---|
| Ctrl+Alt+Shift+S | Duraklat/devam et |
| Ctrl+Alt+Shift+R | RESET gönder; SM odakta değilse dönüşe ertele |
| Ctrl+Alt+Shift+M | Aktif pencereyi SM penceresi olarak işaretle |
| Ctrl+Alt+Shift+H | SM öndeyse ana PC'ye geç (SM simge durumuna küçülür); değilse SM'e dön |
| Ctrl+F11 | SM sekmesinde Waterfox tam ekranını aç/kapat (F11 SM'e gider) |
| Ctrl+Alt+Shift+Q | Köprü penceresini kapat |

Ctrl+Alt+Shift+H geçişi tuşlar bırakılınca yapılır; böylece bırakma olayları
hâlâ öndeki pencereye gider ve SM'de takılı Ctrl/Alt kalmaz. Ana PC'de
Alt+Tab ile SM penceresine dönmek de çalışır; köprü SM penceresi öne gelince
kendiliğinden devreye girer, duraklatmaya gerek yoktur.

Host ve guest tray menülerinde çıkış ve yeniden yükleme seçenekleri bulunur.
SM içinde Ctrl+Alt+Shift+R, doğal modifier'lar dahil acil bırakma yapar.
Host bu kombinasyonu yakalıyorsa SM'deki alıcının tray menüsünü kullan.

Köprü aktifken Alt+F4 SM'deki uygulamaya yönlenebilir.
Pencere kapatma komutu 3 saniyede kapanmayan pencereye WinKill uygular.

Win+L ve Ctrl+Alt+Del bu köprüyle desteklenmez. Ctrl+Alt+Del için
Horizon'un kendi gönderim düğmesini kullan.

## Testler

### Otomatik kontroller (host)

```powershell
python tests\test_bridge.py
powershell -ExecutionPolicy Bypass -File tests\test_fullscreen_ui.ps1
```

Python 3 ve AutoHotkey v2 gerekir. Farklı AHK yolu ikinci argümanla verilebilir.
Tüm AHK dosyaları /validate ile yükleme kontrolünden geçer. Regresyon testi
gerçek host/guest işleyici gövdelerini çıkarıp sahte giriş/çıkışla çalıştırır;
klavye olayı enjekte etmez veya Horizon açmaz. Modifier koruması, tekrar
bastırma, ortak sol/sağ kaynaklar, odak dışı RESET, canlılık zamanlaması,
watchdog, sekme başlığı kontrolü, pencere işaretleme filtresi, tek Win
vuruşu ve otomatik başlatma kısayolu kontrol edilir. Bu testler tarayıcı veya uzak masaüstü iletimini kanıtlamaz.

### Taşıyıcı iletimi

1. Host köprüsünü ve guest alıcısını kapat.
2. SM'de `Test_ShowKeys.ahk`, host'ta `Test_BridgeKeys.ahk` çalıştır.
3. Uzak masaüstü alanına tıkla.
4. Host'taki 1–9, 0, q, w tuşları F13–F24 gönderir; F1 hepsini tarar.
5. Özellikle F13–F17 ve **F24** için hem down hem up görüldüğünü doğrula.
6. Host testinden Esc, SM göstergesinden Ctrl+Alt+Shift+X ile çık.

### Gerçek Alt+Tab / Ctrl+Tab yolunun teşhisi

Ayrıntılı kısa deneme: [LOGGER_DENEME.md](LOGGER_DENEME.md).

1. SM'e alıcı, config, Bridge_Logger ve Diag_SM_Receiver dosyalarını birlikte
   kopyala; **Diag_SM_Receiver.ahk** çalıştır. Test_ShowKeys kapalı kalmalı.
2. Host'ta **Diag_CtrlTab.ahk** çalıştır. Gerçek host köprüsü logger ile yeniden
   başlar. SM'nin Waterfox penceresine tıkla ve **F8** ile işaretle.
3. Düz Tab, sol Alt+Tab, Ctrl+Tab ve Ctrl+Shift+Tab dene.
4. Her makinede `%TEMP%\ShortcutBridgeLogs` altında ayrı bir log oluşur:
   host-*.log ve guest-*.log. Tray menüsündeki "Log klasorunu ac" da kullanılabilir.
5. RAW satırları Windows olaylarını; HOST HANDLER/DOWN satırları köprü
   işlemini; GUEST RX/TX satırları alım ve yerel gönderimi gösterir.
   STATE satırındaki target=0 / matched=0 hedef pencere sorununun kanıtıdır;
   titleMatch=0 ön plandaki sekmenin başlığının SM_TITLE_MATCH içermediğini gösterir.
6. Teşhis bitince tray'den çık ve normal host/alıcıyı yeniden başlat.

Logger harf/rakam veya pencere başlığı kaydetmez; yalnızca Tab, modifier,
F8 ve F13–F24 olaylarını, pencere kimliğini ve süreç adını kaydeder. Windows
observer hook'u olayları engellemez ve dosyaya yazmayı timer'a bırakır.
Başka bir hook önce yutarsa RAW kaydı da eksik kalabilir; logda olay yokluğu
tek başına Horizon'a ilişkin kesin bir teşhis değildir. `injected` bayrağı
olayın fiziksel tuştan geldiğinin/gelmediğinin tek başına kanıtı değildir.

Normal başlangıçta host scripti argümansız açılırsa target=0 ile pasiftir.
**SM_Baslat.bat** hedef pencere açar; mevcut pencereyi teşhis modunda F8 ile
bağlamak, pencere eşleşmesini modifier kısayollarından bağımsız sınar.

### Canlı oturum kabul kontrolü

- Alt+Tab: art arda seçim, Alt+Shift+Tab ile geri seçim ve Alt bırakınca onay.
- Ctrl+Tab / Ctrl+Shift+Tab; ardından Ctrl+C/V ve normal Tab/Shift+Tab.
- Shift ile büyük harf ve AltGr ile @, [, ], {, }.
- Win+D/E/R; sol/sağ Win ve Shift'in birlikte basılı tutulması.
- Alt'ı 15 saniye tut: bağlantı sağlıklıyken seçici erken kapanmamalı.
- Alt basılıyken fareyle başka host penceresine geç, tuşları bırak ve geri dön:
  SM'de takılı tuş kalmamalı.
- Host durdurulduğunda guest tuttuğu tuşları zaman aşımı sonunda bırakmalı.
- Normal Waterfox penceresinde yerel kısayollar çalışmaya devam etmeli.
- Tek Win: SM'de Başlat açılmalı. Win+D ve Win+E'de Başlat açılmamalı.
- SM'de Win+D masaüstünü göstermeli; Win+Tab görev görünümünü açmalı.
- SM'de Ctrl+T, Ctrl+Alt+T, Ctrl+Alt+C, Ctrl+W ve F5 SM'deki uygulamaya gitmeli;
  Waterfox'ta yeni sekme açılmamalı, sekme kapanmamalı, sayfa yenilenmemeli.
- SM'de F11 SM'deki uygulamaya gitmeli; Ctrl+F11 Waterfox tam ekranını açıp kapatmalı.
- Ctrl+C / Ctrl+V ile yerel PC ile SM arasında kopyala-yapıştır çalışmalı.
- Ctrl+Alt+Shift+S SM'deyken de köprüyü duraklatmalı.
- Bağlı oturumda host tray ipucu "aktif" göstermeli (sekme başlığı eşleşiyor).
- Aynı Waterfox penceresinde başka sekmeye geç: Alt+Tab host'ta çalışmalı;
  Horizon sekmesine dönünce yeniden SM'e gitmeli.

## Yeni kısayol ve dağıtım

Önce kısayolun gerçekten tarayıcıda kaldığını ölç. Ardından
Bridge_Config içindeki uygun tap satırını aç. Guest alanı temel tuş adıdır
(ör. w); Ctrl gibi doğal modifier'ı tekrar ekleme.
F17 RESET, F24 canlılık, F18–F23 Waterfox kısayollarının taşınması için
ayrılmıştır; boş taşıyıcı kalmadı. Waterfox'un yuttuğu bir tuş taşınmıyorsa
onu `CARRY_KEYS` listesinin **sonuna** ekle ve `BRIDGE_PROTOCOL_VERSION`'ı artır.
F14 için ayrıca ^Tab hotkey'i ekleme; ortak Tab kapısı kullanılır.

Değişiklikleri her iki tarafa aynı config ile dağıt ve scriptleri yeniden başlat.
Eski `.7z` arşivleri, v4 paketi ve eski teşhis logu `_arsiv/` klasöründedir
(git dışı). Güncel Git kaynaklarını veya v5 paketini kullan. Paket
`python build_release.py` ile üretilir ve üretim sırasında testlerden geçer.

## v6 değişiklikleri

- SM sekmesinde Waterfox'un hiçbir kısayolu çalışmıyor; tuşlar F18–F23
  taşıma protokolüyle SM'e gidiyor (Ctrl+T, Ctrl+Alt+T, Ctrl+Alt+C, F5, F11...).
- Waterfox tam ekranı SM sekmesinde Ctrl+F11 ile açılıp kapanıyor.
- Win+D, Win+E gibi Win kombinasyonları SM'e ulaşıyor; Win+Tab da köprüleniyor.
- Ctrl+C/V/X/Insert pano eşitlemesi için doğal yoldan geçmeye devam ediyor.
- Kontrol kısayolları taşıma hotkey'lerinin öncelikli varyantı oldu ve SM'deyken
  de fiziksel Ctrl+Alt+Shift ile çalışıyor.
- Ctrl+Alt+Shift+H: SM ile ana PC arasında tek tuşla geçiş.
- Teşhis logu taşıma hanelerini yalnızca "CARRY" olarak kaydediyor.
- Test betiği uyarıları konsola yazdırıyor; tek başına doğrulanan logger
  artık ekranda bir uyarı penceresi açıp beklemiyor.

## v5 değişiklikleri

- Tek Win basışı SM'de Başlat menüsünü açıyor (`GUEST_WIN_TAP_FIX`).
- Canlılık sinyali artık tutuşun ilk 100 ms'inde değil, 1. saniyesinde gidiyor.
- Sekme kontrolü: köprü yalnızca başlığı `SM_TITLE_MATCH` içeren sekmede çalışıyor.
- Ctrl+Alt+Shift+M yalnızca `SM_ALLOWED_EXES` içindeki tarayıcıları bağlıyor.
- Açılışta yalnızca gerçek Waterfox pencereleri (`MozillaWindowClass`) bekleniyor.
- Alıcı tray menüsüne "Oturum açılışında başlat" eklendi (UI Access destekli).
- `tools/probe_keyboard_lock.py`: Waterfox'un Keyboard Lock desteğini ölçer.
- Logger STATE satırına `titleMatch` bayrağı eklendi; başlığın kendisi kaydedilmez.
- Eski arşivler, v4 paketi ve teşhis logu depodan çıkarıldı.

## v4 düzeltmeleri

- Gerçek hold down/up gönderimlerine Blind eklendi.
- Teşhis scripti gerçek köprü yoluna bağlandı; eski F18 açıklamaları kaldırıldı.
- F24 canlılık sinyali ve odak dönüşünde ertelenmiş RESET eklendi.
- Sol/sağ kaynaklar ayrı izleniyor; köprülenen up olayları SM odağında yutuluyor.
- Normal RESET doğal modifier'ları topluca bırakmıyor.
- Yapılandırmada taşıyıcı çakışmaları ve geçersiz zamanlama kontrol ediliyor.
- Profil user.js yedeği tekrar uygulamada korunuyor.

## Waterfox üst kenar paneli

Tam ekranda fare üst kenara geldiğinde araç çubuklarının açılmasını
`fullscreen-ui.css` engeller. **F6** paneli gösterir, **Esc** gizler. SM
sekmesinde F6 ve F11 SM'e gider; tam ekran için orada Ctrl+F11 kullan.
F11 yine tam ekrandan çıkıp girmeyi sağlar. Klavyeyle adres çubuğuna
odaklanma gibi yerleşik erişim yolları korunur; kapatılan şey fare tetikleyicisidir.

Mevcut profilde yalnızca bu ayarı uygulamak için:

```powershell
powershell -ExecutionPolicy Bypass -File Waterfox_SM\Apply_Waterfox_Prefs.ps1 -FullscreenOnly
```

Waterfox'u tamamen kapatıp yeniden açtıktan sonra geçerli olur.
Kurulum `chrome/userChrome.css` ve `user.js` içine işaretli blok ekler;
mevcut özelleştirmeleri korur. Tekrar çalıştırmak bloğu çoğaltmaz.
`-FullscreenOnly -Remove` yalnızca bu blokları kaldırır.
CSS dosyasını elle silme; diğer özelleştirmelerin aynı dosyada olabilir.

Bu profilin tüm tam ekran Waterfox pencerelerine uygulanır. Fareyi üst
kenara götürünce içerik alanı değişmemeli; F6/Esc ile açma-kapama bilerek
istekte bulunduğunda gerçekleşir. Tarayıcı güncellemesi CSS seçicilerini
veya kısayol davranışını değiştirirse yeniden kontrol edilmelidir.
