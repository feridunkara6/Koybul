/// DENİZCİLİK AKADEMİSİ — alan modeli (v2.0 vizyonu, kurucu onayı 2026-08).
///
/// Rehberler UYGULAMANIN İÇİNDE yazılmıştır: hiçbir kılavuz kitaptan,
/// siteden veya telifli kaynaktan kopyalanmaz. İçerik genel denizcilik
/// bilgisidir ve resmî eğitimin/sertifikasyonun yerine GEÇMEZ — her rehberin
/// altında bu not görünür.
library;

import 'package:dockly_ui/dockly_ui.dart' show DocklyIconData;

/// Tek rehber: başlık + bir cümlelik özet + maddeler + (varsa) kaptan notu.
class Guide {
  const Guide({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.points,
    this.note,
  });

  /// Kalıcı kimlik (dilden bağımsız) — bağlam kancaları bunu kullanır.
  final String id;

  final DocklyIconData icon;
  final String title;

  /// Bir cümlelik özet — listede başlığın altında görünür.
  final String summary;

  /// Uygulanabilir maddeler (sıralı; her biri tek başına anlamlı).
  final List<String> points;

  /// Kaptan notu — vurgulanacak tek uyarı/ipucu (yoksa null).
  final String? note;
}

/// Rehber metni (dile göre değişen kısım). İkon ve kimlik dilden bağımsızdır.
class GuideText {
  const GuideText({
    required this.title,
    required this.summary,
    required this.points,
    this.note,
  });

  final String title;
  final String summary;
  final List<String> points;
  final String? note;
}
