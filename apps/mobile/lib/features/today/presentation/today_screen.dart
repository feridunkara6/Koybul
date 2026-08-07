import 'package:dockly_api/dockly_api.dart' show GeoPoint;
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../../../core/origin_provider.dart';
import '../../../core/widgets/section_card.dart';
import '../../checklist/presentation/checklist_sheet.dart';
import '../../weather/presentation/weather_card.dart';

/// BUGÜN sekmesi v0 (v2.0 vizyonu, kurucu onayı 2026-08): günlük alışkanlık
/// merkezi. v0 içeriği GERÇEK verilerle sınırlıdır: günün hava/rüzgâr kartı
/// (MET Norway) + seyir öncesi kontrol listesi. Akıllı koy önerisi motoru
/// sonraki pakette bu ekrana eklenir — "yakında" vaadi ÇİZİLMEZ (0-uydurma).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    // Hava konumu: GPS varsa gerçek konum, yoksa haritada bakılan bölge.
    final GeoPoint? pos =
        ref.watch(devicePositionProvider) ?? ref.watch(originProvider);
    final DateTime now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            // GÜN IŞIĞI başlık kartı — Bugün'ün sıcak kimliği (onaylı tema).
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFF59E0B), Color(0xFFF97316)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    t.navToday,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${now.day}.${now.month}.${now.year}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFF3E0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Günün havası — konum bilinmiyorsa dürüst yönlendirme.
            if (pos != null)
              WeatherCard(position: pos, accent: const Color(0xFFF59E0B))
            else
              SectionCard(
                icon: DocklyIcons.infoOutline,
                title: t.wxTitle,
                child: Text(
                  t.todayNoPos,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            // Seyir öncesi kontrol listesi — çıkmadan tamamla.
            SectionCard(
              icon: DocklyIcons.checkCircle,
              title: t.checklistTooltip,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const ValueKey<String>('today-checklist'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: () => showChecklistSheet(context),
                  child: Text(t.checklistOpenBtn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
