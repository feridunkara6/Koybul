/// DERİA tonoz doluluğu (Göcek) — kaynak: Türkiye Çevre Ajansı, deria.gov.tr.
/// Rezervasyon UYGULAMADA YAPILMAZ; arayüz kaptanı deria.gov.tr'ye yönlendirir.
class DeriaAvailability {
  const DeriaAvailability({
    required this.fetchedAt,
    required this.forDate,
    required this.attribution,
    required this.coves,
  });

  /// Sunucunun kaynaktan çektiği an — arayüz bayatlık kararını buna göre verir.
  final DateTime fetchedAt;

  /// Hangi gece için (giriş günü, TR).
  final String forDate;

  final String attribution;
  final List<DeriaCove> coves;

  /// Slug için doluluk; yoksa null (gösterge çizilmez).
  DeriaCove? forSlug(String slug) {
    for (final DeriaCove c in coves) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  factory DeriaAvailability.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['coves'] as List<dynamic>?) ?? <dynamic>[];
    return DeriaAvailability(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      forDate: json['forDate'] as String,
      attribution: (json['attribution'] as String?) ?? '',
      coves: raw
          .map((dynamic e) => DeriaCove.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Tek koyun tonoz doluluğu.
class DeriaCove {
  const DeriaCove({
    required this.slug,
    required this.free,
    required this.total,
  });

  final String slug;

  /// Bu gece için müsait şamandıra sayısı.
  final int free;

  /// Toplam kapasite.
  final int total;

  factory DeriaCove.fromJson(Map<String, dynamic> json) => DeriaCove(
        slug: json['slug'] as String,
        free: (json['free'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );
}
