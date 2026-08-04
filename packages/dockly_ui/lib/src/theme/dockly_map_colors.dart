import 'package:flutter/material.dart';

/// Harita `location_type` başına kanonik pin renkleri (docs/09 §1.4, foundation §7).
///
/// KURAL: Bu renkler yalnız harita semantiğine rezervedir; amenity/rozet vb. başka
/// hiçbir yerde yeniden kullanılamaz (docs/09 §1.4). Uygulama kodunda ham hex yasak
/// olduğundan (docs/09 §0) pin renkleri buradan tüketilir.
///
/// Mapbox annotation API'si renk olarak ARGB `int` beklediğinden değerler int olarak
/// tutulur; `forType` ayrıca Flutter `Color` döndürür (lejant/rozet kullanımı için).
abstract final class DocklyMapColors {
  /// Harita zemini — karo yüklenene dek görünen renk. Gri yerine açık deniz
  /// tonu: yüklenmemiş alan "bozuk" değil "henüz gelmemiş su" gibi durur
  /// (algılanan hız, 2026-08). Aquarelle stilinin deniz tonuyla uyumludur.
  static const Color seaBackground = Color(0xFFBFD9EE);

  /// Bilinmeyen/yeni tip için güvenli varsayılan (marka birincil).
  static const int _fallbackArgb = 0xFF0C7BDC;

  static const Map<String, int> _argbByType = <String, int>{
    'private_marina': 0xFF0C7BDC, // Özel Marina
    'municipal_marina': 0xFF3B82F6, // Belediye Marinası
    'municipal_pier': 0xFF6366F1, // Belediye İskelesi
    'guest_mooring': 0xFF2EC4B6, // Misafir Bağlama Noktası
    'restaurant_pier': 0xFFF97316, // Restoran İskelesi
    'fuel_pier': 0xFFEAB308, // Yakıt İskelesi
    'boat_club': 0xFF8B5CF6, // Tekne Kulübü
    'mooring_point': 0xFFEF4444, // Bağlama Noktası (ürün kararı: gri↔kırmızı takas)
    'buoy': 0xFF64748B, // Şamandıra (ürün kararı: gri↔kırmızı takas)
  };

  /// Küme (cluster) rozeti rengi (docs/09 §1.4: baskın tip; v1'de marka birincil).
  static const int clusterArgb = 0xFF0C7BDC;

  /// Küme baloncuğu ÜLKE renkleri — kibar/pastel tasarım: açık pastel dolgu
  /// üstünde canlı vurgu (halka + sayı metni). Türkiye mavi, Yunanistan turkuaz;
  /// bilinmeyen/eski veri nötr açık ton + marka vurgusu (geriye uyumlu).
  /// Yeni ülke eklenince iki tabloya birer satır eklenir.
  static const Map<String, int> _clusterFillArgbByCountry = <String, int>{
    'TR': 0xFFE3F2FF, // pastel mavi
    'GR': 0xFFDEF6F2, // pastel turkuaz
  };
  static const Map<String, int> _clusterAccentArgbByCountry = <String, int>{
    'TR': 0xFF0C7BDC, // marka birincil
    'GR': 0xFF0E8577, // koyultulmuş turkuaz — açık zeminde okunur (kontrast)
  };
  static const int _clusterFillFallbackArgb = 0xFFEDF2F8; // nötr açık gri-mavi

  /// Baloncuk dolgusu (açık pastel) — web.
  static Color clusterFillColorForCountry(String countryCode) =>
      Color(clusterFillArgbForCountry(countryCode));

  /// Baloncuk vurgusu: halka + sayı (canlı ton) — web.
  static Color clusterAccentColorForCountry(String countryCode) =>
      Color(clusterAccentArgbForCountry(countryCode));

  /// Mapbox (native) baloncuk dolgusu — annotation API ARGB int ister.
  static int clusterFillArgbForCountry(String countryCode) =>
      _clusterFillArgbByCountry[countryCode] ?? _clusterFillFallbackArgb;

  /// Mapbox (native) baloncuk vurgusu (halka + sayı).
  static int clusterAccentArgbForCountry(String countryCode) =>
      _clusterAccentArgbByCountry[countryCode] ?? clusterArgb;

  /// Pin dolgu ikonu ve halkası (docs/09 §1.4: ikon/halka #FFFFFF).
  static const int strokeArgb = 0xFFFFFFFF;

  /// Mapbox annotation için ARGB int. Bilinmeyen tip → marka birincil (fallback).
  static int argbForType(String type) => _argbByType[type] ?? _fallbackArgb;

  /// Flutter `Color` (lejant, rozet, widget kullanımı için).
  static Color forType(String type) => Color(argbForType(type));

  /// Kanonik tip kodları kümesi (test/lejant için).
  static Iterable<String> get knownTypes => _argbByType.keys;
}
