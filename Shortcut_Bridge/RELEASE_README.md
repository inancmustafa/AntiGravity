# Shortcut Bridge v6 — Logger'sız kullanım paketi

Günlük kullanım paketidir. Logger, teşhis başlatıcıları ve test araçları
çıkarılmıştır; log dosyası üretmez. Tuş eşlemeleri ve zamanlamalar depodaki
kaynakla aynıdır ve paket üretilirken regresyon testlerinden geçer.

## Kullanım

1. ZIP'i bir klasöre çıkar. AutoHotkey v2 her iki bilgisayarda kurulu olmalı.
2. Eski host/guest köprülerini ve logger'ları tray menülerinden kapat.
   Farklı klasörlerden iki köprü aynı anda çalışmamalı.
3. SM'e Guest_SM_Receiver.ahk ve Bridge_Config.ahk dosyalarını aynı klasöre
   kopyala (eski dosyaların üzerine yaz) ve Guest_SM_Receiver.ahk'yi çalıştır.
   **Host v6 ile SM'deki eski alıcı birlikte çalışmaz:** Waterfox kısayolları
   SM'e ulaşmaz. İki tarafı birlikte güncelle.
4. SM'de alıcının tray menüsünden **Oturum açılışında başlat**'ı işaretle.
   Sonraki oturumlarda kendiliğinden açılır. AutoHotkey UI Access bileşeniyle
   kuruluysa kısayol onu kullanır; alıcı yönetici pencerelerinde de çalışır.
5. Host'ta SM_Baslat.bat dosyasını çalıştır.
6. İki tray ipucunda da **v6** görünmeli; Horizon sekmesindeyken host "aktif" demeli.
7. Mevcut Waterfox penceresini kullanacaksan Host_PC_Bridge.ahk'yi aç,
   SM penceresine tıkla ve Ctrl+Alt+Shift+M ile bağla. Yalnızca Waterfox ve
   Firefox pencereleri bağlanabilir.

## Kısayollar

- SM sekmesinde **Waterfox'un hiçbir kısayolu çalışmaz**; Ctrl+T, Ctrl+Alt+T,
  Ctrl+Alt+C, Ctrl+W, F5, F11, Win+D ve benzerleri SM'e gider.
- **Ctrl+F11** Waterfox tam ekranını açıp kapatır (F11 SM'e gider).
- **Ctrl+C / Ctrl+V / Ctrl+X** doğal yoldan geçer; Horizon kopyala-yapıştırı
  bunlarla eşitler.
- **Ctrl+Alt+Shift+H** SM'den ana PC'ye geçer (SM penceresi simge durumuna
  küçülür); ana PC'deyken tekrar basınca SM'e döner.
- Ctrl+Alt+Shift+S duraklatır; Ctrl+Alt+Shift+R sıfırlar; Ctrl+Alt+Shift+Q
  köprü penceresini kapatır.
- Tek Win basışı SM'de Başlat menüsünü açar. Başlat açılıp hemen kapanıyorsa
  Bridge_Config.ahk'de `GUEST_WIN_TAP_FIX := false` yap.
- Köprü yalnızca Horizon sekmesinde çalışır; başka sekmeye geçince tuşlar
  host'ta kalır ve tray "bekliyor: sekme 'Horizon' değil" gösterir. Bağlı
  oturumda tray "aktif" demiyorsa Bridge_Config.ahk'deki `SM_TITLE_MATCH`'i
  düzelt veya `""` yap, dosyayı iki tarafa da kopyala.

## Waterfox üst paneli

Daha önce uygulanan ayar geçerliyse tekrar kurulum gerekmez.
Yeni profilde yalnızca fareyle üst kenar açılmasını kapatmak için:

```powershell
powershell -ExecutionPolicy Bypass -File Waterfox_SM\Apply_Waterfox_Prefs.ps1 -FullscreenOnly
```

Waterfox yeniden açılınca geçerli olur. F6 paneli gösterir; Esc gizler.
SM sekmesinde F6 SM'e gider; tam ekrandan çıkmak için Ctrl+F11 kullan.
Mevcut profil özelleştirmeleri korunur.

## Bilinen durum

- Alt+Tab için sol Alt kullanılır; AltGr doğal yoldan iletilir.
- Win+L ve Ctrl+Alt+Del köprülenmez.
- Host ve SM aynı Bridge_Config.ahk dosyasını kullanmalı; sürümü farklıysa
  alıcı "Taşıma dizisi reddedildi" uyarısı gösterir.
- Adres çubuğuna odaklanma ayırt edilmez; orada çalışırken köprüyü duraklat.
- Waterfox, Alt+Tab ve Win'i sayfaya bırakamıyor; bu yüzden köprü gerekli.
- Eski .7z arşivlerini ve eski paketleri bu paketle karıştırma.

Pakette SHA256SUMS.txt dosyası, her kullanım dosyasının SHA-256 değerini içerir.
