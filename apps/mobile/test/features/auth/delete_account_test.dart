import 'package:dockly_core/dockly_core.dart';
import 'package:dockly_mobile/features/auth/application/auth_controller.dart';
import 'package:dockly_mobile/features/auth/presentation/account_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_fakes.dart';

/// HESAP SİLME testleri (Faz 0 — mağaza ve KVKK şartı).
///
/// Kritik nokta: silme BAŞARISIZSA kaptan "silindi" sanmamalı. Sunucu ucu
/// vardı ama butonu yoktu; şimdi buton var, davranışı burada kilitleniyor.
Widget _app(FakeAuthRepository repo) {
  return ProviderScope(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(repo),
      signedInAuthOverride(),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AccountSection())),
    ),
  );
}

void main() {
  testWidgets('oturum açıkken "Hesabımı sil" görünür (mağaza şartı)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('acc-delete')), findsOneWidget);
    expect(find.text('Hesabımı sil'), findsOneWidget);
  });

  testWidgets('oturum YOKKEN silme düğmesi çizilmez',
      (WidgetTester tester) async {
    // signedInAuthOverride verilmez → giriş kartı görünür.
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AccountSection())),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('acc-delete')), findsNothing);
  });

  testWidgets('tek dokunuşla silinmez: önce onay penceresi çıkar, vazgeçilebilir',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('acc-delete')));
    await tester.pumpAndSettle();

    // Pencere neyin silineceğini VE neyin kalacağını söyler.
    expect(find.text('Hesabını silmek üzeresin'), findsOneWidget);
    expect(find.textContaining('geri alınamaz'), findsOneWidget);
    expect(find.textContaining('yalnız bu telefonda'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('acc-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repo.deleted, isFalse);
  });

  testWidgets('onaylanınca hesap silinir ve bilgi verilir',
      (WidgetTester tester) async {
    final FakeAuthRepository repo = FakeAuthRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('acc-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('acc-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleted, isTrue);
    expect(find.text('Hesabın silindi.'), findsOneWidget);

    // SnackBar zamanlayıcısını akıt (CI dersi: bekleyen Timer kırmızı yapar).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('SUNUCU SİLEMEZSE sahte başarı gösterilmez, dürüst hata çıkar',
      (WidgetTester tester) async {
    // En tehlikeli senaryo: ağ koptu, hesap duruyor, ama kaptan silindi sandı.
    final FakeAuthRepository repo = FakeAuthRepository()
      ..deleteError = const NetworkFailure('bağlantı yok');
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('acc-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('acc-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.deleted, isFalse);
    expect(find.text('Hesabın silindi.'), findsNothing);
    expect(find.textContaining('Hesap silinemedi'), findsOneWidget);
    // Düğme yeniden kullanılabilir olmalı — kaptan tekrar deneyebilsin.
    final Widget button =
        tester.widget(find.byKey(const ValueKey<String>('acc-delete')));
    expect((button as TextButton).onPressed, isNotNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
