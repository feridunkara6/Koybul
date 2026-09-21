/**
 * JWS gövdesi çözme (P2) — İMZA DOĞRULAMASI YAPMAZ, bilinçli olarak.
 *
 * GÜVENLİK MODELİ (premium v3 raporu §9 uygulama notu): Apple'dan gelen hiçbir
 * JWS'e içeriği üzerinden GÜVENİLMEZ. Bildirim (App Store Server Notification)
 * yalnızca bir TETİKTİR: içinden originalTransactionId çıkarılır, gerçek durum
 * her zaman App Store Server API'sine (bizim anahtarımızla, TLS üzerinden)
 * sorulur ve veritabanına O yazılır. Böylece Apple kök sertifika zinciri
 * doğrulaması taşımadan sahte bildirim etkisiz kalır: sahte gövde en fazla
 * gereksiz bir Apple sorgusu tetikler, asla premium veremez.
 * API yanıtının içindeki JWS'ler ise zaten Apple'ın TLS kanalından gelir.
 */
export function decodeJwsPayload(jws: string): Record<string, unknown> | null {
  const parts = jws.split('.');
  if (parts.length !== 3) return null;
  try {
    const json = Buffer.from(parts[1], 'base64url').toString('utf8');
    const parsed: unknown = JSON.parse(json);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}
