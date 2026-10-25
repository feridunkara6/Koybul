import 'package:dockly_api/dockly_api.dart' show PublicBoatCard;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../marina/application/marina_controller.dart' show localBoatTypeId;
import '../../profile/presentation/captain_profile_screen.dart';
import '../application/boat_card_controller.dart';
import 'boat_model_art.dart';
import 'boat_photo_header.dart' show BoatArtView;
import 'boat_type_art.dart';

/// TEKNE KARTI — herkese açık tekne profili (Sosyalleşme Hafta 2, kurucu
/// onayı 2026-10-24).
///
/// Marina topluluğundaki tekne satırına dokununca açılır. Çizim kuralları
/// Teknem'dekiyle BİREBİR aynıdır: marka+model KATI eşleşirse MODELE ÖZEL
/// çizim, yoksa türün genel çizimi; etiket her zaman doğruyu söyler.
/// Borda adı aynı ayrı katmandır. Konum/iletişim/sicil bu ekranda YOKTUR;
/// teknik satır yalnız sahibi "teknik bilgileri paylaş" dediyse doludur.
/// ANİMASYON YOK (talimat gereği).
class BoatCardScreen extends ConsumerWidget {
  const BoatCardScreen({required this.boatId, super.key});

  final String boatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<PublicBoatCard> async = ref.watch(publicBoatCardProvider(boatId));
    return Scaffold(
      appBar: AppBar(title: Text(t.bcTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.bcLoadFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(publicBoatCardProvider(boatId)),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (PublicBoatCard b) => _Body(b: b, t: t),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.b, required this.t});

  final PublicBoatCard b;
  final L10n t;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color sub = theme.colorScheme.onSurfaceVariant;

    // ÇİZİM SEÇİMİ — Teknem'deki onaylı kuralın aynısı: model KATI eşleşirse
    // model çizimi; yoksa tür çizimi (tür bilinmiyorsa dürüst yelkenli).
    final BoatArtEntry? modelArt = boatModelArt(brand: b.brand, model: b.model);
    final BoatArtEntry art =
        modelArt ?? boatTypeArt(localBoatTypeId(b.boatTypeCode), lengthM: b.lengthM);

    final List<String> specs = <String>[
      if (b.brand != null && b.model != null)
        '${b.brand} ${b.model}'
      else if (b.brand != null)
        b.brand!,
      if (b.lengthM != null) '${_num(b.lengthM!)} m',
      if (b.buildYear != null) '${b.buildYear}',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        // ÇİZİM + BORDA ADI — fotoğraf yok: başkasının teknesinin fotoğrafı
        // bu sürümde taşınmaz (foto altyapısı ayrı iş, gizlilik ayrı karar).
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor.withValues(alpha: .4)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFF4FAFF), Color(0xFFDCEBF5)],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 26, 6, 6),
                child: SizedBox(
                  height: 170,
                  child: BoatArtView(
                    key: ValueKey<String>(modelArt != null
                        ? 'boat-card-model-${art.id}'
                        : 'boat-card-${art.id}'),
                    entry: art,
                    boatName: b.name,
                  ),
                ),
              ),
              // KAYNAK ETİKETİ — dürüstlük çipi (Teknem'dekiyle aynı dil).
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
                    modelArt != null
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(b.name,
            key: const ValueKey<String>('bc-name'),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          <String>[
            if (specs.isNotEmpty) specs.join(' · '),
            if (b.marinaName != null) '⚓ ${b.marinaName}',
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: sub),
        ),
        const SizedBox(height: 14),
        // KAPTAN — dokununca kaptan kartı (Hafta 1B ekranı) açılır.
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey<String>('bc-captain'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => CaptainProfileScreen(userId: b.captainUserId)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: DocklyColors.accentTurquoise.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: DocklyIcon(DocklyIcons.sailing,
                          size: 18, color: DocklyColors.accentTurquoise),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(b.captainName,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(t.levelLabel(b.captainLevelCode),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: DocklyColors.accentTurquoise,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  DocklyIcon(DocklyIcons.arrowForward, size: 15, color: sub),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // GİZLİLİK DÜRÜSTLÜĞÜ: kart neden var, ne zaman kaybolur.
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF2DFAE)),
          ),
          child: Text(
            '🔒 ${t.bcPrivacyNote}',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF7A5B12)),
          ),
        ),
      ],
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1).replaceAll('.', ',');
}
