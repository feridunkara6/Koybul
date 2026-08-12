import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart' show NetworkFailure;
import 'package:dockly_mobile/features/deria/domain/deria_gateway.dart';

/// `DeriaGateway` yerine geçen sahte. Varsayılan: boş liste (kutu çizilmez).
class FakeDeriaGateway implements DeriaGateway {
  FakeDeriaGateway({this.result, this.fail = false});

  DeriaAvailability? result;
  bool fail;
  int calls = 0;

  @override
  Future<DeriaAvailability> availability() {
    calls++;
    if (fail) return Future<DeriaAvailability>.error(const NetworkFailure());
    return Future<DeriaAvailability>.value(result ?? emptyDeria());
  }
}

DeriaAvailability emptyDeria() => DeriaAvailability(
      fetchedAt: DateTime.now().toUtc(),
      forDate: '2026-08-12',
      attribution: 'DERİA — Türkiye Çevre Ajansı (deria.gov.tr)',
      coves: const <DeriaCove>[],
    );

/// 2026-08-12 canlı yanıtından örnek değerler.
DeriaAvailability sampleDeria({DateTime? fetchedAt}) => DeriaAvailability(
      fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
      forDate: '2026-08-12',
      attribution: 'DERİA — Türkiye Çevre Ajansı (deria.gov.tr)',
      coves: const <DeriaCove>[
        DeriaCove(slug: 'boynuzbuku-samandira-sahasi', free: 66, total: 84),
        DeriaCove(slug: 'tersane-adasi-koyu', free: 2, total: 8),
        DeriaCove(slug: 'gobun-samandira-sahasi', free: 0, total: 11),
      ],
    );
