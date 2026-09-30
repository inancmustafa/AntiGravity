# Shortcut Bridge v5 — Logger'sız kullanım paketi

Günlük kullanım paketidir. Logger, teşhis başlatıcıları ve test araçları
çıkarılmıştır; log dosyası üretmez. Tuş eşlemeleri ve zamanlamalar depodaki
kaynakla aynıdır ve paket üretilirken regresyon testlerinden geçer.

## Kullanım

1. ZIP'i bir klasöre çıkar. AutoHotkey v2 her iki bilgisayarda kurulu olmalı.
2. Eski host/guest köprülerini ve logger'ları tray menülerinden kapat.
   Farklı klasörlerden iki köprü aynı anda çalışmamalı.
3. SM'e Guest_SM_Receiver.ahk ve Bridge_Config.ahk dosyalarını aynı klasöre
   kopyala (v4 dosyalarının üzerine yaz) ve Guest_SM_Receiver.ahk'yi çalıştır.
4. SM'de alıcının tray menüsünden **Oturum açılışında başlat**'ı işaretle.
   Sonraki oturumlarda kendiliğinden açılır. AutoHotkey UI Access bileşeniyle
   kuruluysa kısayol onu kullanır; alıcı yönetici pencerelerinde de çalışır.
5. Host'ta SM_Baslat.bat dosyasını çalıştır.
6. İki tray ipucunda da **v5** görünmeli; Horizon sekmesindeyken host "aktif" demeli.
7. Mevcut Waterfox penceresini kullanacaksan Host_PC_Bridge.ahk'yi aç,
   SM penceresine tıkla ve Ctrl+Alt+Shift+M ile bağla. Yalnızca Waterfox ve
   Firefox pencereleri bağlanabilir.

Host tray menüsünde başlatma, duraklatma, sıfırlama ve çıkış seçenekleri vardır.
Ctrl+Alt+Shift+S duraklatır; Ctrl+Alt+Shift+R sıfırlar.
Ctrl+Alt+Shift+Q köprü penceresini kapatır.

## v5 ile gelenler

- **Tek Win basışı SM'de Başlat menüsünü açar.** Win+D gibi kombinasyonlarda
  ek vuruş yapılmaz. Başlat açılıp hemen kapanıyorsa Bridge_Config.ahk'de
  `GUEST_WIN_TAP_FIX := false` yap.
- **Köprü yalnızca Horizon sekmesinde çalışır.** Aynı pencerede başka bir sekmeye
  geçince Alt+Tab, Ctrl+Tab ve Win host'ta kalır; tray "bekliyor: sekme 'Horizon'
  değil" gösterir. Bağlı oturumda tray "aktif" demiyorsa sekme başlığı farklıdır:
  Bridge_Config.ahk'deki `SM_TITLE_MATCH`'i düzelt veya `""` yap, dosyayı iki
  tarafa da kopyala.
- Kısa tuş vuruşlarında gereksiz canlılık sinyali gönderilmez.
- Yanlış pencerenin Ctrl+Alt+Shift+M ile bağlanması engellenir.

## Waterfox üst paneli

Daha önce uygulanan ayar geçerliyse tekrar kurulum gerekmez.
Yeni profilde yalnızca fareyle üst kenar açılmasını kapatmak için:

```powershell
powershell -ExecutionPolicy Bypass -File Waterfox_SM\Apply_Waterfox_Prefs.ps1 -FullscreenOnly
```

Waterfox yeniden açılınca geçerli olur. F6 paneli gösterir; Esc gizler.
Mevcut profil özelleştirmeleri korunur.

## Bilinen durum

- Alt+Tab için sol Alt kullanılır; AltGr doğal yoldan iletilir.
- Win+L ve Ctrl+Alt+Del köprülenmez.
- Host ve SM aynı Bridge_Config.ahk dosyasını kullanmalı.
- Adres çubuğuna odaklanma ayırt edilmez; orada çalışırken köprüyü duraklat.
- Waterfox, Alt+Tab ve Win'i sayfaya bırakamıyor (Keyboard Lock yalnızca tarayıcı
  kısayollarını kapsıyor); bu yüzden köprü gerekli.
- Eski .7z arşivlerini ve v4 paketini bu paketle karıştırma.

Pakette SHA256SUMS.txt dosyası, her kullanım dosyasının SHA-256 değerini içerir.
