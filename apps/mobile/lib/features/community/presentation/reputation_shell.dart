import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/reputation_controller.dart';

/// Denizci profili ekranlarının ORTAK parçaları: sayı biçimi ve
/// yükleniyor / hata / veri ayrımı.
///
/// NEDEN VAR: bu ekranların hepsi `valueOrNull ?? empty` yazıyordu. Sonuç:
/// sunucuya ulaşılamadığında 2.840 puanlı bir kaptan "Henüz katkın yok"
/// görüyordu — hata, boşlukla birebir aynı görünüyordu (inceleme bulgusu
/// 2026-08). Artık üç durum üç ayrı şey gösterir.

/// Binlik ayraçlı sayı: 2840 → "2.840" (tr) · "2,840" (en) · "2 840" (ru).
/// Ayraç DİLDEN gelir; sabit nokta yazmak İngilizce'de 2.840'ı 2,84 gibi
/// okuturdu (inceleme bulgusu 2026-08).
String formatCount(L10n t, int value) {
  final bool negative = value < 0;
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(t.thousandsSep);
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}

/// Ondalıklı deniz mili: 12.4 → "12" · 4.4 → "4,4" · 8.0 → "8".
/// 10 milden büyükse ondalık ANLAMSIZDIR (plan mesafesi zaten yaklaşıktır).
String formatNm(L10n t, double nm) {
  if (nm >= 10) return formatCount(t, nm.round());
  final String s = nm.toStringAsFixed(1);
  return s.endsWith('.0')
      ? s.substring(0, s.length - 2)
      : s.replaceFirst('.', t.decimalSep);
}

/// Özet gelmediğinde ne yapılacağını tek yerde karara bağlar.
///
/// [onData] YALNIZ gerçekten veri varken çağrılır. Yükleme ve hata halleri
/// çağırana bırakılmaz — altı ekranda altı farklı davranış çıkmasın.
class ReputationScope extends ConsumerWidget {
  const ReputationScope({
    required this.onData,
    this.loading,
    this.error,
    super.key,
  });

  final Widget Function(ReputationSummary summary) onData;

  /// Yüklenirken çizilecek (verilmezse ince bir ilerleme halkası).
  final Widget? loading;

  /// Hata halinde çizilecek (verilmezse standart uyarı + "Tekrar dene").
  final Widget? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReputationSummary> async = ref.watch(reputationSummaryProvider);
    final ReputationSummary? data = async.valueOrNull;
    if (data != null) return onData(data);
    if (async.hasError) {
      return error ?? const ReputationErrorBox();
    }
    return loading ?? const ReputationLoadingBox();
  }
}

class ReputationLoadingBox extends StatelessWidget {
  const ReputationLoadingBox({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey<String>('reputation-loading'),
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

/// "Bilgiler yüklenemedi · Tekrar dene" — hatayı BOŞLUKTAN ayıran kutu.
///
/// [onRetry] verilmezse yalnız özet tazelenir. Dökümü ya da not listesini
/// gösteren ekranlar KENDİ sağlayıcılarını da tazelemek zorundadır; aksi halde
/// düğme çalışıyormuş gibi görünür ama hiçbir şey değişmez (inceleme bulgusu).
class ReputationErrorBox extends ConsumerWidget {
  const ReputationErrorBox({this.onRetry, this.isRetrying, super.key});

  final VoidCallback? onRetry;

  /// Kendi kaynağı yeniden yükleniyor mu. Verilmezse ÖZETİN durumuna bakılır
  /// — döküm/liste tazelenirken de tepki görünsün diye çağıran bunu geçer.
  final bool? isRetrying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final ThemeData theme = Theme.of(context);
    // Yeniden denenirken düğme yerine ilerleme halkası: kaptan tepki
    // görmediği için üst üste basıp aynı isteği çoğaltmasın.
    final bool retrying =
        isRetrying ?? ref.watch(reputationSummaryProvider).isLoading;
    return Container(
      key: const ValueKey<String>('reputation-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          DocklyIcon(DocklyIcons.infoOutline, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.reputationLoadFailed,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          if (retrying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              key: const ValueKey<String>('reputation-retry'),
              onPressed: onRetry ?? () => ref.invalidate(reputationSummaryProvider),
              child: Text(t.retryLabel),
            ),
        ],
      ),
    );
  }
}
