# Shortcut Bridge v4 — Logger'sız kullanım paketi

Kullanıcı tarafından Alt+Tab ve Ctrl+Tab çalıştığı doğrulanan sürümün
teşhis bileşenleri çıkarılmış paketidir. Tuş eşlemeleri ve zamanlamalar korunur.
Log dosyası üretmez; logger, teşhis başlatıcıları ve test araçları içermez.

## Kullanım

1. ZIP'i bir klasöre çıkar. AutoHotkey v2 her iki bilgisayarda kurulu olmalı.
2. Eski host/guest köprülerini ve logger'ları tray menülerinden kapat.
   Farklı klasörlerden iki köprü aynı anda çalışmamalı.
3. SM'e yalnızca Guest_SM_Receiver.ahk ve Bridge_Config.ahk dosyalarını
   aynı klasöre kopyala; Guest_SM_Receiver.ahk dosyasını çalıştır.
4. Host'ta SM_Baslat.bat dosyasını çalıştır.
5. Mevcut Waterfox penceresini kullanacaksan Host_PC_Bridge.ahk'yi aç,
   SM penceresine tıkla ve Ctrl+Alt+Shift+M ile bağla.
   F8 yalnızca eski teşhis moduna aitti; bu pakette ayrılmamıştır.

Host tray menüsünde başlatma, duraklatma, sıfırlama ve çıkış seçenekleri vardır.
Ctrl+Alt+Shift+S duraklatır; Ctrl+Alt+Shift+R sıfırlar.
Ctrl+Alt+Shift+Q köprü penceresini kapatır.

## Waterfox üst paneli

Daha önce uygulanan ayar geçerliyse tekrar kurulum gerekmez.
Yeni profilde yalnızca fareyle üst kenar açılmasını kapatmak için:

```powershell
powershell -ExecutionPolicy Bypass -File Waterfox_SM\Apply_Waterfox_Prefs.ps1 -FullscreenOnly
```

Waterfox yeniden açılınca geçerli olur. F6 paneli gösterir; Esc gizler.
Mevcut profil özelleştirmeleri korunur.

## Bilinen durum

- **Tek Win basışı SM'de Başlat menüsünü açmıyor.** Kullanıcı isteğiyle
  bu sürümde düzeltilmedi. Başlat düğmesine fareyle tıklanabilir.
- Alt+Tab için sol Alt kullanılır; AltGr doğal yoldan iletilir.
- Win+L ve Ctrl+Alt+Del köprülenmez.
- Host ve SM aynı Bridge_Config.ahk dosyasını kullanmalı.
- Köprü pencereyi izler; aynı pencerenin adres çubuğu/başka sekmesi
  seçildiğinde otomatik olarak durmaz.
- Eski Shortcut_Bridge.7z arşivini bu paketle karıştırma.

Pakette SHA256SUMS.txt dosyası, her kullanım dosyasının SHA-256 değerini içerir.
