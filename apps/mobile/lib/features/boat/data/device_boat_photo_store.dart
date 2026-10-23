import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/boat_photo_store.dart';

/// `BoatPhotoStore`'un cihaz uygulaması: image_picker ile seçer, uygulamanın
/// belgeler klasörüne SABİT adla kopyalar (tek tekne = tek fotoğraf; yenisi
/// eskisinin üstüne yazar, artık dosya birikmez). Tüm işlemler en iyi çaba —
/// hata durumunda null/sessiz dönüş, uygulama akışı bozulmaz (depolama
/// sözleşmesi, boat_storage ile aynı ilke).
class DeviceBoatPhotoStore implements BoatPhotoStore {
  const DeviceBoatPhotoStore();

  static const String _fileName = 'tekne_fotografi.jpg';

  Future<String> _targetPath() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  @override
  Future<String?> load() async {
    try {
      final String path = await _targetPath();
      return File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> pick({required bool fromCamera}) async {
    try {
      // Boyut sınırı: kimlik kartı için 1600px fazlasıyla yeter; depolama ve
      // bellek dostu (fotoğraf cihazda kaldığı için kota da kullanıcıya ait).
      final XFile? picked = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return null; // vazgeçti — mevcut fotoğraf korunur
      final String target = await _targetPath();
      await File(picked.path).copy(target);
      // Önbellekli Image.file aynı yolu tazelesin diye dokunma zamanı yeter;
      // ekran tarafı yol+sürüm anahtarıyla yeniden çizer.
      return target;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final String path = await _targetPath();
      final File f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // en iyi çaba — sessizce geç
    }
  }
}
