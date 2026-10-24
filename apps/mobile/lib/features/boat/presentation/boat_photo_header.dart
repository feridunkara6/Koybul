import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/boat_photo_controller.dart';
import '../application/my_boat_controller.dart';
import '../domain/my_boat.dart';
import 'boat_model_art.dart';
import 'boat_type_art.dart';

/// TEKNE FOTOĞRAFI başlığı (kurucu onayı 2026-10-23, Teknem paketi +
/// Çizim Kütüphanesi Paket 1 entegrasyonu).
///
/// Kimlik kartının üst bölümü: kullanıcı fotoğrafı varsa onu; yoksa marka+
/// model KATI eşleşirse MODELE ÖZEL çizimi; o da yoksa türün genel çizimini
/// gösterir. Sol üstteki KAYNAK ETİKETİ her zaman doğruyu söyler ("SENİN
/// FOTOĞRAFIN" / "MODEL ÇİZİMİ" / "TİP ÇİZİMİ"). BORDA ADI ayrı katmandır:
/// teknenin adı çizimin kıçına yakın, gövde çizgisini izleyerek yazılır; ad
/// yoksa hiçbir şey yazılmaz; fotoğrafın üstüne yazı bindirilmez.
/// Fotoğraf YALNIZ CİHAZDA durur (gizlilik kararı A); bakım/tekne verisine
/// hiçbir bağı yoktur. ANİMASYON YOK (talimat gereği).
class BoatPhotoHeader extends ConsumerWidget {
  const BoatPhotoHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final BoatPhotoState photo = ref.watch(boatPhotoProvider);
    final MyBoat? boat = ref.watch(myBoatProvider);
    final String? path = photo.path;
    final bool hasPhoto = path != null && File(path).existsSync();
    // ÇİZİM SEÇİMİ (onaylı kural): model KATI eşleşirse model çizimi,
    // eşleşmezse türün genel çizimi (gulet boya göre varyant alır).
    final BoatArtEntry? modelArt =
        boatModelArt(brand: boat?.brand, model: boat?.model);
    final BoatArtEntry art = modelArt ??
        boatTypeArt(boat?.typeId, lengthM: boat?.lengthM);
    final String boatName = boat?.name?.trim() ?? '';

    return SizedBox(
      // ÇİZİM MODU DAHA YÜKSEK (TestFlight geri bildirimi 2026-10-24:
      // "çizimler küçük ve uzakta kalıyor"): fotoğraf 148, çizim 210.
      height: hasPhoto ? 148 : 210,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasPhoto)
            Image.file(
              File(path),
              key: ValueKey<String>('boat-photo-v${photo.version}'),
              fit: BoxFit.cover,
              // Dosya okunamazsa sessizce illüstrasyona eşdeğer boşluk —
              // kart asla kırık görsel simgesi göstermez.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          else
            Padding(
              // Dar kenar payı: tekne kadrajı doldursun (aynı geri bildirim).
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: _BoatArtView(
                key: ValueKey<String>(modelArt != null
                    ? 'boat-art-model-${art.id}'
                    : 'boat-art-${art.id}'),
                entry: art,
                boatName: boatName,
              ),
            ),
          // Alt gölge YALNIZ fotoğrafta: rozet her fotoğrafta okunur kalır.
          // Çizim modunda gölge yok — borda adı ve gövde renkleri kararmaz.
          if (hasPhoto)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00071626), Color(0xCC071626)],
              ),
            ),
          ),
          // KAYNAK ETİKETİ — dürüstlük çipi.
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xB8071626),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                hasPhoto
                    ? '📷 ${t.btSrcUser}'
                    : modelArt != null
                        ? '🖊️ ${t.btSrcModel}'
                        : '🎨 ${t.btSrcIllustration}',
                style: const TextStyle(
                  color: Color(0xFFCFE9FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: const Color(0xEBFFFFFF),
              shape: const CircleBorder(),
              child: InkWell(
                key: const ValueKey<String>('boat-photo-btn'),
                customBorder: const CircleBorder(),
                onTap: () => showBoatPhotoSheet(context),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Text('📷', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fotoğraf kaynağı alt sayfası: çek / galeri / illüstrasyona dön + gizlilik
/// sözü. Vazgeçmek mevcut fotoğrafı DEĞİŞTİRMEZ.
Future<void> showBoatPhotoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext _) => const _BoatPhotoSheetBody(),
  );
}

class _BoatPhotoSheetBody extends ConsumerWidget {
  const _BoatPhotoSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final L10n t = ref.watch(l10nProvider);
    final bool hasPhoto = ref.watch(boatPhotoProvider).path != null;

    Widget option({
      required String keyValue,
      required String icon,
      required String label,
      required Future<void> Function() onTap,
    }) {
      return ListTile(
        key: ValueKey<String>(keyValue),
        dense: true,
        leading: Text(icon, style: const TextStyle(fontSize: 20)),
        title: Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        onTap: () async {
          final NavigatorState nav = Navigator.of(context);
          await onTap();
          if (nav.mounted) nav.pop();
        },
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(t.btPhotoTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            option(
              keyValue: 'boat-photo-camera',
              icon: '📷',
              label: t.btPhotoCamera,
              onTap: () async =>
                  ref.read(boatPhotoProvider.notifier).pick(fromCamera: true),
            ),
            option(
              keyValue: 'boat-photo-gallery',
              icon: '🖼️',
              label: t.btPhotoGallery,
              onTap: () async =>
                  ref.read(boatPhotoProvider.notifier).pick(fromCamera: false),
            ),
            if (hasPhoto)
              option(
                keyValue: 'boat-photo-clear',
                icon: '🎨',
                label: t.btPhotoIllustration,
                onTap: () async => ref.read(boatPhotoProvider.notifier).clear(),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9EC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF2DFAE)),
              ),
              child: Text(
                '🔒 ${t.btPhotoPrivacy}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF7A5B12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Çizim + BORDA ADI katmanı (onaylı rapor §5-6).
///
/// Çizim, kendi en-boy oranında ortalanır; ad, girişteki onaylı çapa
/// noktasında (kıça yakın, sheer eğimli) AYRI Flutter katmanı olarak
/// yazılır — aynı model çizimi her kullanıcıda kendi tekne adıyla görünür.
/// flutter_svg <text> çizmediği için bu katman zorunlu ve bilinçlidir.
class _BoatArtView extends StatelessWidget {
  const _BoatArtView({
    required this.entry,
    required this.boatName,
    super.key,
  });

  final BoatArtEntry entry;
  final String boatName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: entry.vbW / entry.vbH,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // Ölçek: viewBox birimi → ekran pikseli (fill ile birebir).
            final double s = c.maxWidth / entry.vbW;
            final double boxW = 132 * s;
            final double boxH = 16 * s;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SvgPicture.string(entry.svg, fit: BoxFit.fill),
                if (boatName.isNotEmpty)
                  Positioned(
                    left: (entry.nameX - entry.vbX) * s - boxW / 2,
                    // Metin tabanı ~ çapa y'si; kutu merkezi 3 birim üstte.
                    top: (entry.nameY - entry.vbY - 3) * s - boxH / 2,
                    width: boxW,
                    height: boxH,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: entry.nameRot * math.pi / 180,
                        child: Center(
                          child: Text(
                            boatName,
                            key: const ValueKey<String>('boat-art-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF123A52),
                              fontSize: 9 * s,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.6 * s,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
