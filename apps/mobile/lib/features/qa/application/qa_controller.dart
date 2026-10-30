import 'package:dockly_api/dockly_api.dart' show QaDetail, QaFeed;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/api_qa_gateway.dart';
import '../domain/qa_gateway.dart';

/// SORU-CEVAP orkestrasyonu (Blog V1 — kurucu onayı 2026-10-23).
///
/// Erişim kuralları SUNUCUDADIR: akış herkese; detay sunucunun verdiği
/// full/teaser kararıyla çizilir; yazma denemesi ücretsiz üyede 403 alır ve
/// ekran paywall'a yönlendirir. İstemci hiçbir kilidi kendi başına "açamaz".

final Provider<QaGateway> qaGatewayProvider = Provider<QaGateway>((ref) {
  return ApiQaGateway(
    ref.watch(qaApiProvider),
    () => ref.read(authRepositoryProvider).validAccessToken(),
  );
});

/// Akış sorgusu anahtarı (2026-10-30): kategori + arama + sayfa. Kayıt tipi
/// değerce eşitlenir — aynı sorgu ikinci kez ağa gitmez.
typedef QaFeedKey = ({String? category, String query, int page});

/// Akış — sayfalı + aramalı aile. autoDispose: ekrandan çıkınca istek
/// zinciri salınır; elle yenileme ref.invalidate ile.
/// NOT: sol taraf tür BİLEREK çıkarımda (CI dersi, invalid_assignment).
final qaFeedProvider =
    FutureProvider.autoDispose.family<QaFeed, QaFeedKey>((ref, QaFeedKey key) {
  return ref.watch(qaGatewayProvider).feed(
        category: key.category,
        query: key.query.trim().length >= 2 ? key.query.trim() : null,
        page: key.page,
      );
});

/// Soru detayı — erişim kararı (full/teaser) sunucudan gelir.
final AutoDisposeFutureProviderFamily<QaDetail, String> qaDetailProvider =
    FutureProvider.autoDispose.family<QaDetail, String>((ref, String id) {
  return ref.watch(qaGatewayProvider).detail(id);
});
