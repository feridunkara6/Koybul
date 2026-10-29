import 'package:dockly_api/dockly_api.dart' show FeedItem;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_strings.dart';
import '../application/feed_controller.dart';
import 'feed_cards.dart';

/// TOPLULUK AKIŞI ekranı (SP-3b, kurucu onayı 2026-10-31).
///
/// Bugün'deki akış bölümünün "Tümünü gör" hedefi. Yalnız hesaplı kullanıcı
/// ulaşır (bölüm misafire çizilmez); boş akış takibe/keşfe davet eder.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n t = ref.watch(l10nProvider);
    final AsyncValue<List<FeedItem>> async = ref.watch(feedProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.fdTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(t.actionFailed, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(feedProvider),
                child: Text(t.retryLabel),
              ),
            ],
          ),
        ),
        data: (List<FeedItem> items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  t.fdEmpty,
                  key: const ValueKey<String>('feed-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(feedProvider),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int i) =>
                  FeedItemCard(item: items[i]),
            ),
          );
        },
      ),
    );
  }
}
