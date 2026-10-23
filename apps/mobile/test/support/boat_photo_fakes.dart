import 'package:dockly_mobile/features/boat/domain/boat_photo_store.dart';

/// Bellekte tutan sahte fotoğraf deposu (docs/15 kuralı: gerçek dosya
/// sistemi/eklenti — image_picker, path_provider — teste girmez).
class FakeBoatPhotoStore implements BoatPhotoStore {
  FakeBoatPhotoStore({this.stored, this.nextPick});

  /// Kayıtlı fotoğraf yolu (null = fotoğraf yok → illüstrasyon).
  String? stored;

  /// Bir sonraki `pick` çağrısının döndüreceği yol (null = vazgeçti).
  String? nextPick;

  int clearCount = 0;

  @override
  Future<String?> load() async => stored;

  @override
  Future<String?> pick({required bool fromCamera}) async {
    if (nextPick != null) stored = nextPick;
    return nextPick;
  }

  @override
  Future<void> clear() async {
    stored = null;
    clearCount++;
  }
}
