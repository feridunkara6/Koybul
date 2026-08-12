import 'package:shared_preferences/shared_preferences.dart';

import '../domain/boat_storage.dart';
import '../domain/my_boat.dart';

/// `BoatStorage`'ın `shared_preferences` uygulaması. Tekne boyu/su çekimini,
/// adını ve bağlı marinayı cihazda saklar. Tüm işlemler en iyi çaba: hata
/// olursa sessizce geçer (ör. test ortamında eklenti yoksa) — uygulama akışı
/// bozulmaz.
class SharedPrefsBoatStorage implements BoatStorage {
  const SharedPrefsBoatStorage();

  static const String _lenKey = 'boat.lengthM';
  static const String _draftKey = 'boat.draftM';
  static const String _brandKey = 'boat.brand';
  static const String _typeKey = 'boat.typeId';
  static const String _nameKey = 'boat.name';
  // Bağlı marina 4 anahtarla saklanır; DÖRDÜ BİRDEN geçerliyse okunur —
  // yarım kayıt (ör. ad var, koordinat yok) marina yokmuş gibi davranır.
  static const String _marinaIdKey = 'boat.marina.id';
  static const String _marinaNameKey = 'boat.marina.name';
  static const String _marinaLatKey = 'boat.marina.lat';
  static const String _marinaLonKey = 'boat.marina.lon';

  @override
  Future<MyBoat?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final double? len = prefs.getDouble(_lenKey);
      if (len == null) return null;
      HomeMarina? marina;
      final String? mid = prefs.getString(_marinaIdKey);
      final String? mname = prefs.getString(_marinaNameKey);
      final double? mlat = prefs.getDouble(_marinaLatKey);
      final double? mlon = prefs.getDouble(_marinaLonKey);
      if (mid != null && mname != null && mlat != null && mlon != null) {
        marina = HomeMarina(id: mid, name: mname, lat: mlat, lon: mlon);
      }
      return MyBoat(
        lengthM: len,
        draftM: prefs.getDouble(_draftKey),
        brand: prefs.getString(_brandKey),
        typeId: prefs.getString(_typeKey),
        name: prefs.getString(_nameKey),
        homeMarina: marina,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(MyBoat boat) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_lenKey, boat.lengthM);
      final double? draft = boat.draftM;
      if (draft != null) {
        await prefs.setDouble(_draftKey, draft);
      } else {
        await prefs.remove(_draftKey);
      }
      await _setOrRemove(prefs, _brandKey, boat.brand);
      await _setOrRemove(prefs, _typeKey, boat.typeId);
      await _setOrRemove(prefs, _nameKey, boat.name);
      final HomeMarina? marina = boat.homeMarina;
      if (marina != null) {
        await prefs.setString(_marinaIdKey, marina.id);
        await prefs.setString(_marinaNameKey, marina.name);
        await prefs.setDouble(_marinaLatKey, marina.lat);
        await prefs.setDouble(_marinaLonKey, marina.lon);
      } else {
        await prefs.remove(_marinaIdKey);
        await prefs.remove(_marinaNameKey);
        await prefs.remove(_marinaLatKey);
        await prefs.remove(_marinaLonKey);
      }
    } catch (_) {
      // en iyi çaba — sessizce geç
    }
  }

  static Future<void> _setOrRemove(
      SharedPreferences prefs, String key, String? value) async {
    if (value != null && value.trim().isNotEmpty) {
      await prefs.setString(key, value.trim());
    } else {
      await prefs.remove(key);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lenKey);
      await prefs.remove(_draftKey);
      await prefs.remove(_brandKey);
      await prefs.remove(_typeKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_marinaIdKey);
      await prefs.remove(_marinaNameKey);
      await prefs.remove(_marinaLatKey);
      await prefs.remove(_marinaLonKey);
    } catch (_) {
      // en iyi çaba — sessizce geç
    }
  }
}
