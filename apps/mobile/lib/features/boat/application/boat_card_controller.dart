import 'package:dockly_api/dockly_api.dart' show PublicBoatCard;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// TEKNE KARTI sağlayıcısı (Sosyalleşme Hafta 2, kurucu onayı 2026-10-24).
/// Kart kimliksiz okunur; görünürlük/rıza kararları SUNUCUDADIR — görünmeyen
/// tekne buraya hiç ulaşmaz (not-found fırlar, ekran kibarca söyler).
final AutoDisposeFutureProviderFamily<PublicBoatCard, String> publicBoatCardProvider =
    FutureProvider.autoDispose.family<PublicBoatCard, String>((ref, String boatId) {
  return ref.watch(boatsApiProvider).publicCard(boatId);
});
