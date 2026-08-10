import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_mobile/core/l10n/app_locale.dart';
import 'package:dockly_mobile/core/l10n/l10n_strings.dart';
import 'package:dockly_mobile/features/community/presentation/reputation_shell.dart';
import 'package:dockly_mobile/features/community/presentation/sailor_level_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saf yardımcılar: sayı biçimi, sonraki seviye ve baş harfler.
/// Bunlar ekranın "en üst seviyedesin" gibi cümlelerinin TEK karar noktası —
/// ayrı ayrı kilitlenmeleri gerekir.
void main() {
  final L10n tr = l10nOf(AppLocale.tr);
  final L10n en = l10nOf(AppLocale.en);

  group('formatCount', () {
    test('binlik ayraç noktadır (Türkçe biçim)', () {
      expect(formatCount(tr, 2840), '2.840');
      expect(formatCount(tr, 1284), '1.284');
      expect(formatCount(tr, 1000000), '1.000.000');
    });

    test('dört haneden küçükler değişmez', () {
      expect(formatCount(tr, 0), '0');
      expect(formatCount(tr, 7), '7');
      expect(formatCount(tr, 999), '999');
    });

    test('sınır: tam 1000', () => expect(formatCount(tr, 1000), '1.000'));

    test('AYRAÇ DİLDEN gelir: İngilizce virgül, Türkçe nokta', () {
      expect(formatCount(en, 2840), '2,840');
      expect(formatCount(tr, 2840), '2.840');
      expect(formatNm(en, 4.4), '4.4');
      expect(formatNm(tr, 4.4), '4,4');
    });

    test('negatif ceza puanı işaretini korur', () {
      expect(formatCount(tr, -10), '-10');
      expect(formatCount(tr, -2840), '-2.840');
    });
  });

  group('formatNm', () {
    test('10 milden büyükse yuvarlanır ve ayraç alır', () {
      expect(formatNm(tr, 142.4), '142');
      expect(formatNm(tr, 1284.2), '1.284');
    });

    test('10 milden küçükse ondalık virgülle yazılır', () {
      expect(formatNm(tr, 4.4), '4,4');
      expect(formatNm(tr, 0.5), '0,5');
    });

    test('tam sayıda gereksiz ",0" yazılmaz', () {
      expect(formatNm(tr, 8), '8');
      expect(formatNm(tr, 0), '0');
    });
  });

  group('levelForPoints', () {
    test('puandan seviye türetilir (sunucu koduna güvenilmez)', () {
      expect(levelForPoints(0), 'new');
      expect(levelForPoints(149), 'new');
      expect(levelForPoints(150), 'coastal');
      expect(levelForPoints(1499), 'guide');
      expect(levelForPoints(4000), 'pilot');
      expect(levelForPoints(99999), 'pilot');
    });
  });

  group('nextLevelFor', () {
    test('yeni hesap (0 puan) EN ÜST SAYILMAZ — sonraki seviye Kıyı Kaşifi', () {
      // Hata 2026-08: sunucu pointsToNext=null gönderince ekran "En üst
      // seviyedesin" yazıyordu. Karar artık burada, puandan türetiliyor.
      final ({String code, int minPoints})? next = nextLevelFor(0);
      expect(next?.code, 'coastal');
      expect(next!.minPoints - 0, 150);
    });

    test('eşiğin tam üstünde bir sonrakine geçer', () {
      expect(nextLevelFor(150)?.code, 'guide');
      expect(nextLevelFor(149)?.code, 'coastal');
      expect(nextLevelFor(1500)?.code, 'pilot');
    });

    test('yalnız GERÇEKTEN en üstte null döner', () {
      expect(nextLevelFor(3999)?.code, 'pilot');
      expect(nextLevelFor(4000), isNull);
      expect(nextLevelFor(99999), isNull);
    });

    test('eşikler sunucudaki LEVELS ile aynı', () {
      expect(kSailorLevels.map((({String code, int minPoints}) l) => l.minPoints).toList(),
          <int>[0, 150, 600, 1500, 4000]);
    });
  });

  group('ReputationSummary.initials', () {
    String initialsOf(String name) =>
        ReputationSummary.fromJson(<String, dynamic>{'displayName': name}).initials;

    test('ad soyad → iki harf', () => expect(initialsOf('Feridun Kara'), 'FK'));
    test('emoji ile başlayan ad bozulmaz (vekil çifti kırılmaz)',
        () => expect(initialsOf('🐬 Kaptan'), '🐬K'));
    test('tek isim → tek harf', () => expect(initialsOf('Feridun'), 'F'));
    test('üç kelimede ilk ve SON alınır',
        () => expect(initialsOf('Ahmet Mehmet Yılmaz'), 'AY'));
    test('fazla boşluk sorun olmaz', () => expect(initialsOf('  Feridun   Kara '), 'FK'));
    test('ad yoksa BOŞ döner (uydurma harf yok)', () {
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
    test('Türkçe büyütme: i → İ, ı → I', () {
      expect(initialsOf('ibrahim şahin'), 'İŞ');
      expect(initialsOf('ışıl kaya'), 'IK');
    });
  });
}
