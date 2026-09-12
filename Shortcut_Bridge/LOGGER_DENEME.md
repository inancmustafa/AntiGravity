# Alt+Tab / Ctrl+Tab logger denemesi

Bu test, çalışan gerçek köprüyü izler. Eski Test_ShowKeys ve
Test_BridgeKeys scriptleri bu denemede kapalı olmalı.

## 1. SM tarafı

Şu dört dosyayı aynı klasöre kopyala:
- Guest_SM_Receiver.ahk
- Bridge_Config.ahk
- Bridge_Logger.ahk
- Diag_SM_Receiver.ahk

**Diag_SM_Receiver.ahk** dosyasını çalıştır. Mevcut alıcı logger modunda
aynı dosya yolundan yeniden başlar; farklı klasörden çalışan eski alıcı
varsa onu tray menüsünden kapat.

## 2. Host tarafı

**Diag_CtrlTab.ahk** dosyasını çalıştır. SM'nin açık olduğu Waterfox
penceresine tıkla ve **F8** bas. "SM penceresi işaretlendi" mesajını gör.
F8 yalnızca teşhis modunda ayrılmıştır. Hedef bağlanmadan teste başlama.

## 3. Kısa deneme

Her adım arasında tüm tuşları bırakıp iki saniye bekle:
1. Düz Tab bas ve bırak.
2. Sol Alt'ı tut, Tab'a iki kez bas, Alt'ı bırak.
3. Ctrl'ü tut, Tab'a iki kez bas, Ctrl'ü bırak.
4. Ctrl+Shift tut, Tab'a bas, hepsini bırak.

Alt+Tab için SM'de en az iki uygulama penceresi; Ctrl+Tab için SM içinde
sekme değiştirmeyi destekleyen bir uygulamada en az iki sekme açık olsun.
Host'taki Waterfox sekmelerini değiştirmesi başarılı sonuç değildir.

## 4. İki logu paylaş

Her iki makinede alıcı/köprü tray menüsünden **Log klasorunu ac** seç:
- Host: %TEMP%\ShortcutBridgeLogs\host-*.log
- SM: %TEMP%\ShortcutBridgeLogs\guest-*.log

Denemeye ait en yeni iki dosyayı paylaş. Loglar otomatik internete gönderilmez.
Logger metin tuşlarını veya pencere başlıklarını kaydetmez. Dosyalarda script
konumu, süreç adı, pencere kimliği, modifier/Tab ve taşıyıcı olayları bulunur.
Teşhis bitince logger'lı scriptleri tray'den kapat; normal alıcıyı ve
SM_Baslat.bat dosyasını çalıştır.

## Logu nasıl okuyacağız?

| Gözlem | Sonraki bakılacak yer |
|---|---|
| HOST STATE target=0 | Köprü pencereye bağlanmamış |
| HOST STATE matched=0 | Odak yanlış pencerede |
| RAW Tab var, HANDLER_DOWN Tab yok | Host hotkey/gate/hook veya duraklatma |
| HOST down F14 var, GUEST RAW F14 yok | Tarayıcı/Horizon iletimi veya guest gözlem hook'u |
| GUEST RAW F14 var, RX_DOWN F14 yok | Guest alıcı hotkey'i/başka AHK örneği |
| GUEST RX_DOWN F14 var, Ctrl/Alt mantıksal olarak yok | Modifier durumunun kaybolduğu önceki olay |
| GUEST TX_DOWN F14 -> Tab ve doğru modifier var | Yerel gönderim, uygulama odağı veya yetki farkı |

HOST send kaydı yalnızca gönderim isteğinin işlendiğini gösterir; ağ teslim
onayı değildir. GUEST TX de uygulamanın kısayolu uyguladığını kanıtlamaz.
Tick değerleri her makineye özeldir; iki logun saatlerini birebir eşitlemeyiz.
