import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_boat_photo_store.dart';
import '../domain/boat_photo_store.dart';

/// Fotoğraf deposu sağlayıcısı — testte sahte ile override edilir
/// (docs/15 kuralı: gerçek dosya sistemi/eklenti teste girmez).
final Provider<BoatPhotoStore> boatPhotoStoreProvider =
    Provider<BoatPhotoStore>((ref) => const DeviceBoatPhotoStore());

/// Tekne fotoğrafının durumu (kurucu onayı 2026-10-23, Teknem paketi).
///
/// Durum = fotoğrafın dosya yolu; null = fotoğraf yok → kimlik kartı TİP
/// İLLÜSTRASYONUNU çizer. `version` aynı dosya adının üstüne yazılan yeni
/// fotoğrafta görüntü önbelleğini kırmak içindir (Image anahtarına girer).
class BoatPhotoState {
  const BoatPhotoState({this.path, this.version = 0});

  final String? path;
  final int version;
}

class BoatPhotoController extends Notifier<BoatPhotoState> {
  BoatPhotoStore get _store => ref.read(boatPhotoStoreProvider);

  @override
  BoatPhotoState build() {
    unawaited(_restore());
    return const BoatPhotoState();
  }

  Future<void> _restore() async {
    final String? path = await _store.load();
    if (path != null) state = BoatPhotoState(path: path, version: 1);
  }

  /// Kamera/galeri akışı. Kullanıcı vazgeçerse mevcut durum DEĞİŞMEZ.
  Future<bool> pick({required bool fromCamera}) async {
    final String? path = await _store.pick(fromCamera: fromCamera);
    if (path == null) return false;
    state = BoatPhotoState(path: path, version: state.version + 1);
    return true;
  }

  /// Tip illüstrasyonuna dön (fotoğraf silinir; bakım/tekne verisine dokunmaz).
  Future<void> clear() async {
    await _store.clear();
    state = BoatPhotoState(version: state.version + 1);
  }
}

final NotifierProvider<BoatPhotoController, BoatPhotoState> boatPhotoProvider =
    NotifierProvider<BoatPhotoController, BoatPhotoState>(BoatPhotoController.new);
