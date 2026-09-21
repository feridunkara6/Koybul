import { LocationDetail } from './location.types';

/**
 * VİTRİN indirgeme (P1, kurucu onayı 2026-09-21, premium v3 raporu §3):
 * tam detaydan, ücretsiz isteğe dönecek teaser gövdesini üretir.
 *
 * AÇIK KALANLAR (vitrin — "uygulamayı göstererek"):
 *  - kimlik/konum: id, slug, type, status, name, position, geo, priceTier,
 *    is24h, verifiedAt
 *  - 1 kapak fotoğrafı (media.cover) + sayılar (counts / media.count —
 *    "5 fotoğraf Premium'da" rozeti bu sayıyla çizilir)
 *  - GÜVENLİK ÖZETİ: dimensions.depthMinM/depthMaxM, seabed, shelteredDirs,
 *    windExposedDirs, maxBoatLengthM/maxDraftM (pin'de zaten herkese açık)
 *  - puan özeti: rating.avg + rating.count (listelerde zaten görünür)
 *
 * KİLİTLENENLER (Premium): description, amenities, services, contacts, hours,
 * seasons, typeDetails, rating.dimensions, occupancy (DERİA/doluluk),
 * dimensions.capacity.
 *
 * Şekil DEĞİŞMEZ: kilitli alanlar boş/null döner — eski istemci sürümleri
 * çökmeden "bilgi yok" görür; yeni istemci `access: 'teaser'` ile kilit
 * ekranını çizer. Kilitli değerler bu fonksiyona gelen nesneden SİLİNİR;
 * yanıta hiç yazılmadıkları için istemciye inmezler.
 */
export function toTeaserDetail(full: LocationDetail): LocationDetail {
  return {
    ...full,
    description: null,
    dimensions: { ...full.dimensions, capacity: null },
    rating: { avg: full.rating.avg, count: full.rating.count, dimensions: [] },
    amenities: [],
    services: [],
    contacts: [],
    hours: [],
    seasons: [],
    typeDetails: null,
    occupancy: null,
    access: 'teaser',
  };
}
