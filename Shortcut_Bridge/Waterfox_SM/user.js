// ============================================================================
// WATERFOX TERCİHLERİ — SM KULLANIMI İÇİN
// ============================================================================
// Bu dosya MEVCUT (giriş yapılmış) Waterfox profiline kopyalanır.
// Ayrı bir profil OLUŞTURULMAZ — tek hesap, tek profil.
//
// Neden user.js: her açılışta yeniden uygulanır, versiyon kontrolüne girer,
// profil bozulursa tekrar üretilebilir.
//
// ÖNEMLİ: Bu senin GÜNLÜK profilin olduğu için buraya yalnızca günlük
// gezinmeye zarar VERMEYEN tercihler konur. Gizliliği gevşeten ayarlar
// bilinçli olarak DIŞARIDA bırakıldı — aşağıdaki nota bak.
// ============================================================================

// --- Waterfox açılışta SM linkine gitsin ------------------------------------
// Waterfox'u kendin açtığında doğrudan Horizon portalına düşersin.
// (Tam ekran ve köprü YALNIZCA SM_Baslat.bat ile devreye girer.)
user_pref("browser.startup.page", 1);                 // 1 = anasayfayı aç
user_pref("browser.startup.homepage", "https://vgpu-secure.fnss.com.tr/portal/webclient/#/desktop");

// --- Alt tuşu ve erişim tuşları ---------------------------------------------
// Alt'a tek basış menü çubuğunu odaklamasın. Köprü Alt'ı zaten yutuyor, ama
// köprü kapalı/duraklatılmışken bu emniyet kemeri işe yarar.
// Günlük gezinmeye etkisi yok (menü çubuğu zaten gizli).
user_pref("ui.key.menuAccessKeyFocuses", false);

// --- Tam ekran --------------------------------------------------------------
// "Tam ekrana geçtiniz" bildirimi ve geçiş animasyonu SM görüntüsünü kapatıyor.
user_pref("full-screen-api.warning.timeout", 0);
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");

// ============================================================================
// BİLİNÇLİ OLARAK EKLENMEYENLER
// ============================================================================
// Aşağıdaki ayarlar Horizon web client'ında sorun çıkarsa İŞE YARAR, ama
// günlük gezinmenin gizliliğini zayıflatır. Bu yüzden otomatik uygulanmıyor.
// Gerekirse about:config'den ELLE, geçici olarak değiştir:
//
//   privacy.resistFingerprinting     -> false
//       Waterfox'un en agresif ayarı. Ekran boyutunu ve zaman dilimini
//       sahteler; uzak masaüstü çözünürlük/ölçek hesabını bozabilir.
//       Horizon'da garip görüntü/ölçek sorunu görürsen İLK BURAYA BAK.
//
//   privacy.trackingprotection.enabled -> false
//       Kurumsal portalın bazı istekleri engellenirse.
//
//   gfx.webrender.all                -> true
//   media.hardware-video-decoding.enabled -> true
//       SM görüntüsü takılıyorsa performans için.
// ============================================================================
