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
    // Kütüphanede olmayan boylar çizilmez (komşuya yuvarlama yok).
    expect(boatModelArt(brand: 'Beneteau', model: 'Oceanis 35.1'), isNull);
    expect(boatModelArt(brand: 'Jeanneau', model: 'Sun Odyssey 380'), isNull);
    // Lagoon 400 ayrı (eski) nesildir — 40'ın çizimi ona GÖSTERİLMEZ.
    expect(boatModelArt(brand: 'Lagoon', model: '400 S2'), isNull);
    // Sayısız / boş / alakasız metin eşleşmez.
    expect(boatModelArt(brand: 'Beneteau', model: 'Oceanis'), isNull);
    expect(boatModelArt(brand: null, model: null), isNull);
    expect(boatModelArt(brand: 'Najad', model: '390'), isNull);
    expect(boatModelArt(brand: 'Bavaria', model: '412'), isNull);
    // Sayısız modelde AYIRT EDİCİ ad şarttır: tek başına "Westerly" yetmez.
    expect(boatModelArt(brand: 'Westerly', model: '33'), isNull);
  });

  test('PAKET 2: yeni modeller doğru çizime eşleşir', () {
    String? idOf(String brand, String model) =>
        boatModelArt(brand: brand, model: model)?.id;
    expect(idOf('Beneteau', 'Oceanis 40.1'), 'oceanis_40');
    expect(idOf('Jeanneau', 'Sun Odyssey 410'), 'so_410');
    expect(idOf('Bavaria', 'C42'), 'bavaria_c42');
    expect(idOf('Hanse', '388'), 'hanse_388');
    // Sayısız modeller model ADIYLA eşleşir.
    expect(idOf('Westerly', 'Centaur'), 'centaur');
    expect(idOf('Dufour', 'Arpège'), 'arpege');
    expect(idOf('Dufour', 'Arpege'), 'arpege'); // aksansız yazım da tutar
    expect(idOf('Beneteau', 'First 31.7'), 'first_317');
    expect(idOf('Hallberg-Rassy', '352'), 'hr_352');
    expect(idOf('Comar', 'Comet 910'), 'comet_910');
    expect(idOf('Sirena Marine', 'Azuree 46'), 'azuree_46');
    expect(idOf('Fountaine Pajot', 'Astréa 42'), 'astrea_42');
    expect(idOf('Excess', '11'), 'excess_11');
    expect(idOf('Lagoon', '40'), 'lagoon_40');
    expect(idOf('Sea Ray', 'Sundancer 265'), 'searay_265');
    expect(idOf('Sirena', '48'), 'sirena_48');
    expect(idOf('Jeanneau', 'Merry Fisher 695'), 'mf_695');
    expect(idOf('Quicksilver', '605 Pilothouse'), 'qs_605');
    expect(idOf('Zodiac', 'Medline 6.8'), 'zodiac_68');
    expect(idOf('Highfield', 'Sport 660'), 'highfield_660');
    expect(idOf('Brig', 'Eagle 6.7'), 'brig_67');
  });

  test('katalog bütünlüğü: 40 ayrı model, 40 ayrı gövde, ad çapalı', () {
    expect(kBoatModelCatalog, hasLength(40));
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
    expect(ids, hasLength(40)); // kimlik çakışması yok
    expect(bodies, hasLength(40)); // kopya-boylandırma yok: 40 AYRI geometri
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
