// ============================================================================
// SM'E AYRILMIŞ WATERFOX PROFİLİ — TERCİHLER
// ============================================================================
// Bu dosya SM profilinin kök dizinine kopyalanır (Setup_SM_Profile.ps1 yapar).
//
// Neden user.js, neden about:config değil: user.js HER AÇILIŞTA yeniden
// uygulanır, versiyon kontrolüne girer, profil bozulursa tekrar üretilebilir.
// about:config'de elle yapılan değişiklikler ise tek bir profile gömülüdür.
//
// UYARI: Bu profil YALNIZCA SM için. Normal gezinme için kullanma — buradaki
// gizlilik ayarları bilinçli olarak gevşetilmiştir.
// ============================================================================

// --- Alt tuşu ve erişim tuşları ---------------------------------------------
// Alt'a tek basış menü çubuğunu odaklamasın. Köprü Alt'ı zaten yutuyor, ama
// host script kapalıyken veya duraklatılmışken bu emniyet kemeri işe yarar.
user_pref("ui.key.menuAccessKeyFocuses", false);
user_pref("ui.key.generalAccessKey", -1);

// --- Navigasyon tuşları SM'e ait olmalı -------------------------------------
// Backspace geri gitmesin; SM içinde Backspace normal bir düzenleme tuşudur.
user_pref("browser.backspace_action", 2);

// --- Tam ekran --------------------------------------------------------------
// "Tam ekrana geçtiniz" bildirimi ve geçiş animasyonu SM görüntüsünü kapatıyor.
user_pref("full-screen-api.warning.timeout", 0);
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");

// --- Oturum ve kapatma gürültüsü --------------------------------------------
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");

// --- Waterfox'un agresif gizlilik varsayılanları -----------------------------
// Waterfox, Firefox'tan daha sıkı gizlilik varsayılanlarıyla gelir ve bunlar
// kurumsal web uygulamalarını bozabilir. Horizon client'ta beklenmedik bir
// sorun görürsen İLK BAKACAĞIN YER resistFingerprinting'dir: ekran boyutunu ve
// zaman dilimini sahteleyerek uzak masaüstü çözünürlük/ölçek hesabını bozabilir.
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.trackingprotection.enabled", false);
user_pref("privacy.trackingprotection.pbmode.enabled", false);

// --- Uzak masaüstü canvas'ı için performans ----------------------------------
user_pref("gfx.webrender.all", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("dom.ipc.processCount", 4);
