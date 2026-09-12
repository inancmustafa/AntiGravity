# SM Kısayol Köprüsü — AutoHotkey v2

Waterfox içindeki Horizon HTML/Blast oturumunda yerel Windows veya tarayıcı
tarafından işlenen kısayolları sanal makineye (SM) taşır.

Önceki test notlarına göre Ctrl, Shift ve Alt tek başına SM'e ulaşıyor;
Alt+Tab ve Ctrl+Tab kombinasyonları ise yerelde işleniyordu. Bu gözlem
tarayıcı, Horizon veya ortam değiştiğinde yeniden doğrulanmalıdır.

## Kurulum ve kullanım

1. Host PC ve SM'de AutoHotkey v2 kurulu olmalı.
2. Host'ta bu klasörü tut. `Bridge_Config.ahk` içindeki Waterfox yolu ve
   `SM_URL` ortamına uygun olmalı.
3. SM'e **`Guest_SM_Receiver.ahk` ve `Bridge_Config.ahk` dosyalarını birlikte**
   aynı klasöre kopyala; alıcıyı çalıştır.
4. Host'ta `SM_Baslat.bat` dosyasını çalıştır. Köprü yeni bir Waterfox
   penceresi açar, o pencerenin HWND'sini tutar ve F11 ile tam ekrana geçer.
5. Horizon masaüstüne bağlan ve uzak masaüstü alanına tıkla.
6. Her iki tray ipucunda **v4** görünmeli. Bu gösterge otomatik sürüm
   uzlaşması değildir; iki tarafta aynı yapılandırma dosyası kullanılmalıdır.

Köprü yalnızca işaretlenmiş Waterfox **penceresine** bağlıdır. Aynı pencerenin
başka sekmesine, adres çubuğuna veya Horizon giriş ekranına geçildiğini
algılamaz. Köprü aktifken bu alanlarda çalışmadan önce köprüyü duraklat.

Elle açılmış bir pencereyi bağlamak için o pencereyi öne getir ve
Ctrl+Alt+Shift+M kullan. Diğer Waterfox pencereleri köprülenmez.

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

## Odak kaybı ve takılı tuşlar

- Host, odağın ayrıldığını 100 ms aralıkla kontrol eder; tutulmuş köprü
  durumunu temizler ve RESET'i dönüşe erteler. Odak dışına taşıyıcı göndermez.
- RESET beklerken yeni köprü down olayları kabul edilmez. Dönüşte F17
  gönderildikten sonra köprü yeniden hazırdır.
- Host, tuş tutulduğu sürece saniyede bir F24 yollar. Böylece uzun Alt
  tutuşları, bağlantı sağlıklıyken 8 saniye sonunda kesilmez.
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
| Ctrl+Alt+Shift+Q | Köprü penceresini kapat |

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
```

Python 3 ve AutoHotkey v2 gerekir. Farklı AHK yolu ikinci argümanla verilebilir.
Tüm AHK dosyaları /validate ile yükleme kontrolünden geçer. Regresyon testi
gerçek host/guest işleyici gövdelerini çıkarıp sahte giriş/çıkışla çalıştırır;
klavye olayı enjekte etmez veya Horizon açmaz. Modifier koruması, tekrar
bastırma, ortak sol/sağ kaynaklar, odak dışı RESET, canlılık ve watchdog
kontrol edilir. Bu testler tarayıcı veya uzak masaüstü iletimini kanıtlamaz.

### Taşıyıcı iletimi

1. Host köprüsünü ve guest alıcısını kapat.
2. SM'de `Test_ShowKeys.ahk`, host'ta `Test_BridgeKeys.ahk` çalıştır.
3. Uzak masaüstü alanına tıkla.
4. Host'taki 1–9, 0, q, w tuşları F13–F24 gönderir; F1 hepsini tarar.
5. Özellikle F13–F17 ve **F24** için hem down hem up görüldüğünü doğrula.
6. Host testinden Esc, SM göstergesinden Ctrl+Alt+Shift+X ile çık.

### Gerçek Ctrl+Tab yolunun teşhisi

1. SM'de alıcıyı kapat, `Test_ShowKeys.ahk` aç.
2. Host'ta `Diag_CtrlTab.ahk` çalıştır. Bu, gerçek Host_PC_Bridge'i
   teşhis modunda yeniden başlatır; ayrı bir F18 test yolu kullanmaz.
3. SM penceresine tıkla ve Ctrl+Alt+Shift+M ile işaretle.
4. Düz Tab, Ctrl+Tab, Ctrl+Shift+Tab dene.
5. Düz Tab için F14 çıkmamalı. Ctrl+Tab'da F14 down/up yanında Ctrl;
   ters yönde Ctrl+Shift bulunmalı.
6. Host logu: `%TEMP%\shortcut_bridge.log`. Zamanlar milisaniyelik
   yerel A_TickCount değerleridir; iki bilgisayar arasında doğrudan karşılaştırılmaz.
7. Teşhis bitince host tray'den çık; SM alıcısını ve SM_Baslat.bat'ı aç.

F14 ulaşıyor ama modifier görünmüyorsa iletim zincirini incele.
F14 ve modifier birlikte ulaşıyor ama davranış yanlışsa alıcı sürümünü,
yapılandırmayı ve hedef uygulamayı kontrol et.

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

## Yeni kısayol ve dağıtım

Önce kısayolun gerçekten tarayıcıda kaldığını ölç. Ardından
Bridge_Config içindeki uygun tap satırını aç. Guest alanı temel tuş adıdır
(ör. w); Ctrl gibi doğal modifier'ı tekrar ekleme.
F17 RESET, F24 canlılık için ayrılmıştır. F18–F23 ek kısayollara ayrılabilir.
F14 için ayrıca ^Tab hotkey'i ekleme; ortak Tab kapısı kullanılır.

Değişiklikleri her iki tarafa aynı config ile dağıt ve scriptleri yeniden başlat.
Eski Shortcut_Bridge.7z arşivi bu sürümün dağıtımı değildir; güncel Git
kaynaklarını kullan.

## v4 düzeltmeleri

- Gerçek hold down/up gönderimlerine Blind eklendi.
- Teşhis scripti gerçek köprü yoluna bağlandı; eski F18 açıklamaları kaldırıldı.
- F24 canlılık sinyali ve odak dönüşünde ertelenmiş RESET eklendi.
- Sol/sağ kaynaklar ayrı izleniyor; köprülenen up olayları SM odağında yutuluyor.
- Normal RESET doğal modifier'ları topluca bırakmıyor.
- Yapılandırmada taşıyıcı çakışmaları ve geçersiz zamanlama kontrol ediliyor.
- Profil user.js yedeği tekrar uygulamada korunuyor.
