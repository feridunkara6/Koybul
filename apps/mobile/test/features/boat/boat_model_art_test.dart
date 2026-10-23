import 'package:dockly_mobile/features/boat/presentation/boat_model_art.dart';
import 'package:dockly_mobile/features/boat/presentation/boat_type_art.dart';
import 'package:flutter_test/flutter_test.dart';

/// ÇİZİM KÜTÜPHANESİ testleri (Paket 1, kurucu onayı 2026-10-23).
/// İlke: eşleşme KATIDIR — emin olunamayan metin eşleşmez; kullanıcıya
/// asla yanlış model çizimi gösterilmez.
void main() {
  test('Paket 1: popüler modeller doğru çizime eşleşir', () {
    String? idOf(String brand, String model) =>
        boatModelArt(brand: brand, model: model)?.id;
    expect(idOf('Beneteau', 'Oceanis 38.1'), 'oceanis_38');
    expect(idOf('Beneteau', 'Oceanis 46.1'), 'oceanis_46');
    expect(idOf('Jeanneau', 'Sun Odyssey 349'), 'so_349');
    expect(idOf('Jeanneau', 'Sun Odyssey 449'), 'so_449');
    expect(idOf('Jeanneau', 'Sun Odyssey 36i'), 'so_36i');
    expect(idOf('', 'Bavaria Cruiser 37'), 'bavaria_37');
    expect(idOf('Bavaria', 'Cruiser 46'), 'bavaria_46');
    expect(idOf('Dufour', '412 Grand Large'), 'dufour_412');
    expect(idOf('Hanse', '418'), 'hanse_418');
    expect(idOf('Elan', 'Impression 45'), 'elan_45');
    expect(idOf('Hallberg-Rassy', '38'), 'hr_38');
    expect(idOf('X-Yachts', 'X-372'), 'x_372');
    expect(idOf('Dehler', '36'), 'dehler_36');
    expect(idOf('Lagoon', '42'), 'lagoon_42');
    expect(idOf('Lagoon', '450 F'), 'lagoon_450');
    expect(idOf('Bali', '4.2'), 'bali_42');
    expect(idOf('Azimut', '55 Fly'), 'azimut_55');
    expect(idOf('Jeanneau', 'Merry Fisher 795'), 'mf_795');
    expect(idOf('Quicksilver', 'Activ 675 Open'), 'qs_675');
    expect(idOf('Jeanneau', 'Cap Camarat 7.5 WA'), 'camarat_75');
  });

  test('KATI eşleşme: komşu boy ve bilinmeyen model EŞLEŞMEZ', () {
    // Oceanis 40.1 kütüphanede yok → 38 ya da 46 ÇİZİLMEZ.
    expect(boatModelArt(brand: 'Beneteau', model: 'Oceanis 40.1'), isNull);
    // Sun Odyssey 410 kütüphanede yok (449'un "44"ü 410'u yakalamaz).
    expect(boatModelArt(brand: 'Jeanneau', model: 'Sun Odyssey 410'), isNull);
    // Sayısız / boş / alakasız metin eşleşmez.
    expect(boatModelArt(brand: 'Beneteau', model: 'Oceanis'), isNull);
    expect(boatModelArt(brand: null, model: null), isNull);
    expect(boatModelArt(brand: 'Najad', model: '390'), isNull);
    // Aile başka markaya ait sayıyı sahiplenmez: Bavaria 412 diye model yok
    // ama "41" yalnız Dufour ailesinde — bavaria + 412 eşleşmemeli.
    expect(boatModelArt(brand: 'Bavaria', model: '412'), isNull);
  });

  test('katalog bütünlüğü: 20 ayrı model, 20 ayrı gövde, ad çapalı', () {
    expect(kBoatModelCatalog, hasLength(20));
    final Set<String> ids = <String>{};
    final Set<String> bodies = <String>{};
    for (final BoatArtEntry e in kBoatModelCatalog) {
      ids.add(e.id);
      bodies.add(e.svgBody);
      expect(e.svg, contains('<svg'));
      expect(e.svg, contains('</svg>'));
      expect(e.nameX, greaterThan(0)); // borda adı çapası tanımlı
      expect(e.vbW, greaterThan(0));
    }
    expect(ids, hasLength(20)); // kimlik çakışması yok
    expect(bodies, hasLength(20)); // kopya-boylandırma yok: 20 AYRI geometri
  });

  test('tür çizimleri: 8 tür + gulet BOY varyantı', () {
    expect(boatTypeArt('sail').id, 'sail');
    expect(boatTypeArt('motor').id, 'motor');
    expect(boatTypeArt('catamaran').id, 'catamaran');
    expect(boatTypeArt('daily').id, 'daily');
    expect(boatTypeArt('fishing').id, 'fishing');
    expect(boatTypeArt('rib').id, 'rib');
    expect(boatTypeArt('super').id, 'super');
    // Gulet boy kuralı: 20 m sınırı.
    expect(boatTypeArt('gulet', lengthM: 16).id, 'gulet_std');
    expect(boatTypeArt('gulet', lengthM: 24).id, 'gulet_buyuk');
    // Bilinmeyen tür dürüst varsayılana düşer.
    expect(boatTypeArt(null).id, 'sail');
    expect(boatTypeArt('bilinmeyen').id, 'sail');
  });
}
