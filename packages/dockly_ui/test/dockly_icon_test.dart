import 'package:dockly_ui/dockly_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// `svgMarkup` sözleşmesi (2026-09 harita pin rozetleri): widget dışı çizim
/// yapan tüketiciler (Mapbox rozet PNG üretimi) ikonun TAM SVG belgesini
/// buradan alır — çerçeve 24×24 grid + 2px çizgidir ve gövdeyi içerir.
void main() {
  test('svgMarkup geçerli 24×24 çizgi-ikon belgesi döner', () {
    final String svg = DocklyIcons.sailing.svgMarkup;
    expect(svg, startsWith('<svg '));
    expect(svg, endsWith('</svg>'));
    expect(svg, contains('viewBox="0 0 24 24"'));
    expect(svg, contains('stroke-width="2"'));
    // Gövde gerçekten içeride (boş çerçeve değil).
    expect(svg, contains('<path'));
  });

  test('harita pin glifleri (yeni ikonlar) boş değildir', () {
    for (final DocklyIconData icon in <DocklyIconData>[
      DocklyIcons.lifeBuoy,
      DocklyIcons.pier,
    ]) {
      expect(icon.svgMarkup.length, greaterThan('<svg></svg>'.length));
    }
  });
}
