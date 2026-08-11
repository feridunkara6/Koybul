import 'package:dockly_api/dockly_api.dart';
import 'package:dockly_core/dockly_core.dart';
import 'package:test/test.dart';

import 'support/fake_adapter.dart';

Map<String, dynamic> _detailJson() => <String, dynamic>{
      'id': 'loc-1',
      'slug': 'd-marin-gocek',
      'type': 'private_marina',
      'status': 'published',
      'name': 'D-Marin Göcek',
      'description': 'Açıklama',
      'position': <String, dynamic>{'lat': 36.75, 'lon': 28.95},
      'geo': <String, dynamic>{
        'countryCode': 'TR',
        'adminArea': <String, dynamic>{'id': 'aa', 'name': 'Fethiye', 'province': 'Muğla'},
        'waterBody': <String, dynamic>{'id': 'wb', 'name': 'Göcek Körfezi', 'type': 'gulf'},
      },
      'dimensions': <String, dynamic>{
        'maxBoatLengthM': 40.0,
        'maxDraftM': 5.0,
        'depthMinM': 3.0,
        'depthMaxM': 12.0,
        'capacity': 380,
      },
      'priceTier': 'paid',
      'is24h': true,
      'verifiedAt': '2026-08-01T00:00:00.000Z',
      'rating': <String, dynamic>{
        'avg': 4.6,
        'count': 50,
        'dimensions': <dynamic>[
          <String, dynamic>{'code': 'shelter', 'avg': 5.0},
          <String, dynamic>{'code': 'staff', 'avg': 4.0},
        ],
      },
      'amenities': <dynamic>[
        <String, dynamic>{'code': 'electricity', 'label': 'Elektrik', 'category': 'utility'},
      ],
      'services': <dynamic>[
        <String, dynamic>{'code': 'mooring_assist', 'label': 'Palamar'},
      ],
      'contacts': <dynamic>[
        <String, dynamic>{'type': 'phone', 'value': '+90252', 'isPrimary': true},
      ],
      'hours': <dynamic>[
        <String, dynamic>{'dayOfWeek': 1, 'opensAt': '08:00', 'closesAt': '22:00'},
        <String, dynamic>{'dayOfWeek': 2, 'opensAt': null, 'closesAt': null},
      ],
      'seasons': <dynamic>[
        <String, dynamic>{'opensOn': '05-01', 'closesOn': '10-31'},
      ],
      'typeDetails': <String, dynamic>{
        'kind': 'marina',
        'berthCount': 380,
        'vhfChannel': '72',
        'hasBlueFlag': true,
        'travelLiftCapacityTons': 100.0,
        'craneCapacityTons': null,
        'winterStorage': true,
      },
      'media': <String, dynamic>{'cover': null, 'count': 24},
      'userContext': null,
      'counts': <String, dynamic>{'reviews': 50, 'photos': 24},
      // Veri turu 2026-08 alanları — TEL ÜZERİNDEKİ adları burada kilitlenir.
      // Bunlar olmadan sunucu anahtarı yeniden adlandırsa istemci sessizce
      // null okur ve bütün paket yeşil kalırdı.
      'seabed': 'mud',
      'shelteredDirs': 'K,GB',
    };

void main() {
  late FakeAdapter adapter;
  late LocationsApi api;

  setUp(() {
    adapter = FakeAdapter();
    final client = DocklyClient(baseUrl: 'https://api.dockly.test');
    client.dio.httpClientAdapter = adapter;
    api = LocationsApi(client.dio);
  });

  test('detail: tam DTO parse edilir + path doğru', () async {
    adapter.enqueueJson(200, _detailJson());
    final d = await api.detail('d-marin-gocek');

    expect(d.name, 'D-Marin Göcek');
    expect(d.geo.adminArea?.province, 'Muğla');
    expect(d.geo.waterBody?.type, 'gulf');
    expect(d.dimensions.maxBoatLengthM, 40.0);
    expect(d.dimensions.capacity, 380);
    expect(d.is24h, isTrue);
    expect(d.rating.avg, 4.6);
    expect(d.rating.dimensions.map((RatingDimension r) => r.code), <String>['shelter', 'staff']);
    expect(d.amenities.single.label, 'Elektrik');
    expect(d.services.single.code, 'mooring_assist');
    expect(d.contacts.single.isPrimary, isTrue);
    expect(d.hours.firstWhere((Hour h) => h.dayOfWeek == 2).opensAt, isNull);
    expect(d.seasons.single.opensOn, '05-01');
    expect(d.media.cover, isNull);
    expect(d.counts.reviews, 50);
    expect(d.seabed, 'mud');
    // Korunak AYRI alandır: açık yön anahtarı gelmediği için null KALMALI.
    expect(d.shelteredDirs, 'K,GB');
    expect(d.windExposedDirs, isNull);

    expect(adapter.received.single.path, '/v1/locations/d-marin-gocek');
  });

  test('detail: typeDetails marina ayrımı (sealed)', () async {
    adapter.enqueueJson(200, _detailJson());
    final d = await api.detail('loc-1');
    final td = d.typeDetails;
    expect(td, isA<MarinaTypeDetails>());
    expect((td! as MarinaTypeDetails).berthCount, 380);
    expect((td as MarinaTypeDetails).vhfChannel, '72');
  });

  test('detail: bilinmeyen kind → UnknownTypeDetails (çökmez)', () async {
    final json = _detailJson();
    json['typeDetails'] = <String, dynamic>{'kind': 'heliport', 'foo': 1};
    adapter.enqueueJson(200, json);
    final d = await api.detail('loc-1');
    expect(d.typeDetails, isA<UnknownTypeDetails>());
    expect((d.typeDetails! as UnknownTypeDetails).kind, 'heliport');
  });

  test('detail: 404 → NotFoundFailure', () async {
    adapter.enqueueProblem(404, <String, dynamic>{
      'type': 'https://api.dockly.app/problems/not-found',
      'title': 'Bulunamadı',
      'status': 404,
    });
    final failure = await _capture(() => api.detail('yok'));
    expect(failure, isA<NotFoundFailure>());
  });
}

Future<AppFailure> _capture(Future<void> Function() action) async {
  try {
    await action();
  } on AppFailure catch (failure) {
    return failure;
  }
  throw StateError('beklenen AppFailure fırlatılmadı');
}
