import 'package:flutter/widgets.dart';

/// Tur adımlarının SPOT IŞIĞI hedefleri (harita ekranındaki öğelere takılır).
/// GlobalKey'ler uygulama-ömürlüdür; harita ekranı tek örnek olduğundan
/// çakışma olmaz. Hedef ekranda yoksa ilgili adım spot'suz (yalnız balon)
/// gösterilir — tur asla kırılmaz.
final GlobalKey tourKeyChips = GlobalKey(debugLabel: 'tour-chips');
final GlobalKey tourKeyLocate = GlobalKey(debugLabel: 'tour-locate');
final GlobalKey tourKeySos = GlobalKey(debugLabel: 'tour-sos');
final GlobalKey tourKeySearch = GlobalKey(debugLabel: 'tour-search');
