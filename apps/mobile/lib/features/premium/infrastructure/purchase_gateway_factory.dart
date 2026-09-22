/// Platform seçici (map_platform ile aynı desen): mobilde gerçek StoreKit
/// kapısı, web'de stub. `dart.library.io` web derlemesinde yoktur → stub seçilir.
library;

export 'purchase_gateway_stub.dart'
    if (dart.library.io) 'purchase_gateway_iap.dart' show createPurchaseGateway;
