/// TEKNE ÇİZİM ALTYAPISI + GENEL TÜR ÇİZİMLERİ
/// (kurucu onayı 2026-10-23 — "Modele Özel Tekne Çizim Kütüphanesi" talimatı,
/// prototip + Paket 1 görsel onayları alındı).
///
/// TELİF NOTU: tüm çizimler KENDİ elimizden çıkma ÖZGÜN eserlerdir; hiçbir
/// marka görseli, katalog çizimi ya da fotoğraf kopyalanmamıştır. Markalar
/// ilgili sahiplerinindir; çizimler Koybul'un stilize yorumudur ve üreticiyle
/// bağlantı iddia edilmez.
///
/// MİMARİ (onaylı rapor §6):
/// - SVG vektör, uygulamaya gömülü sabit metin — ağ yok, çevrimdışı çalışır.
/// - BORDA ADI ayrı katmandır: flutter_svg <text> çizmez; ad, çizimin
///   üstünde Flutter yazı katmanı olarak gösterilir. Her girişteki
///   nameX/nameY/nameRot, adın o gövdenin kıçına yakın, sheer eğimini
///   izleyen onaylı konumudur (viewBox koordinatında).
/// - Model bilinmezse buradaki GENEL TÜR çizimi gösterilir ve rozet
///   dürüstçe "TİP ÇİZİMİ" der. Gulet, BOYA göre iki varyant alır.
/// - ANİMASYON YOK (talimat gereği) — çizim doğrudan gösterilir.
library;

/// Tek çizim kaydı — tür ve model çizimleri aynı yapıyı kullanır.
class BoatArtEntry {
  const BoatArtEntry({
    required this.id,
    required this.title,
    required this.families,
    required this.numbers,
    required this.vbX,
    required this.vbY,
    required this.vbW,
    required this.vbH,
    required this.nameX,
    required this.nameY,
    required this.nameRot,
    required this.svgBody,
  });

  final String id;

  /// İnsan-okur ad ("Oceanis 38.1" / "Yelkenli — genel tür").
  final String title;

  /// Model eşleşme anahtarları (tür çizimlerinde boş).
  final List<String> families;
  final List<String> numbers;

  /// viewBox: x, y, genişlik, yükseklik.
  final double vbX, vbY, vbW, vbH;

  /// Borda adının çapa noktası (viewBox koordinatı) ve eğimi (derece).
  final double nameX, nameY, nameRot;

  /// <svg> İÇİ (defs + gövde) — tam belge `svg` ile alınır.
  final String svgBody;

  /// Tam SVG belgesi.
  String get svg => '<svg viewBox="$vbX $vbY $vbW $vbH" '
      'xmlns="http://www.w3.org/2000/svg">$svgBody</svg>';
}

/// Gulet boy eşiği (metre) — 20 m ve üstü "büyük gulet" çizimi alır.
const double kGuletBigLengthM = 20;

/// Tür kimliği → genel çizim. Gulet, [lengthM] ile boy varyantına gider;
/// bilinmeyen/boş tür yelkenliye düşer (boatTypeEmoji ile aynı kural).
BoatArtEntry boatTypeArt(String? typeId, {double? lengthM}) {
  if (typeId == 'gulet') {
    final bool big = (lengthM ?? 0) >= kGuletBigLengthM;
    return kBoatTypeArt[big ? 'gulet_buyuk' : 'gulet_std']!;
  }
  return kBoatTypeArt[typeId] ?? kBoatTypeArt['sail']!;
}

/// GENEL TÜR çizimleri (onaylı dolgulu stil; üreteç: scratchpad arşivi).
const Map<String, BoatArtEntry> kBoatTypeArt = <String, BoatArtEntry>{
  'sail': BoatArtEntry(
    id: 'sail',
    title: 'Yelkenli — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 66, vbY: 36, vbW: 258, vbH: 254,
    nameX: 130.0, nameY: 239.0, nameRot: -2.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="none" stroke="#EAF6FC" s'
      'troke-opacity="0.65" stroke-width="1.1" stroke-linecap="round" d="'
      'M210 48 L282 218 M210 48 L112 222"/> <path fill="#F0F7FD" fill-opa'
      'city="0.96" stroke="#9FBBCD" stroke-width="1" d="M207 56 C 203 104'
      ' 190 158 146 198 L207 198 Z"/> <path fill="none" stroke="#0A2A3D" '
      'stroke-opacity="0.28" stroke-width="1" stroke-linecap="round" d="M'
      '198 104 L207 104 M188 144 L207 144 M172 176 L207 176"/> <path fill'
      '="#E2EEF8" fill-opacity="0.88" stroke="#9FBBCD" stroke-width="1" d'
      '="M213 54 C 232 102 258 164 276 214 L240 211 C 234 152 224 100 213'
      ' 54 Z"/> <path fill="none" stroke="#B9D2E2" stroke-width="3" strok'
      'e-linecap="round" d="M209 210 L209 46"/> <path fill="none" stroke='
      '"#B9D2E2" stroke-width="3" stroke-linecap="round" d="M209 201 L146'
      ' 203"/> <path fill="url(#iceG)" stroke="#0A2A3D" stroke-width="1" '
      'd="M100 224 C 150 220 232 217 280 216 L281 246 C 250 254 158 255 1'
      '14 250 C 105 243 101 234 100 224 Z"/> <path fill="none" stroke="#0'
      'A2A3D" stroke-opacity="0.5" stroke-width="1" stroke-linecap="round'
      '" stroke-linejoin="round" d="M103 227 C 152 223 234 220 279 219"/>'
      ' <path fill="none" stroke="#27506B" stroke-width="3" stroke-lineca'
      'p="round" d="M104 248 C 160 252.5 244 250.5 279 244.5"/> <path fil'
      'l="#9CC0D6" stroke="#0A2A3D" stroke-width="1" d="M192 252 C 190 26'
      '6 189 275 189 281 L207 282 C 207 275 206 265 205 252 Z"/> <path fi'
      'll="#9CC0D6" stroke="#0A2A3D" stroke-width="1" d="M134 252 L130 27'
      '4 L138 275 L142 252 Z"/> <path fill="none" stroke="#FFFFFF" stroke'
      '-opacity="0.4" stroke-width="1.6" stroke-dasharray="7 5" d="M74 25'
      '2 L318 252"/> <path fill="none" stroke="#FFFFFF" stroke-opacity="0'
      '.3" stroke-width="2" stroke-linecap="round" d="M70 262 Q 90 258 11'
      '0 262 T 150 262 T 190 262 T 230 262 T 270 262 T 310 262"/> <path f'
      'ill="none" stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="2"'
      ' stroke-linecap="round" d="M84 274 Q 104 270 124 274 T 164 274 T 2'
      '04 274 T 244 274 T 284 274"/>',
  ),
  'motor': BoatArtEntry(
    id: 'motor',
    title: 'Motoryat — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 52, vbY: 108, vbW: 288, vbH: 182,
    nameX: 138.0, nameY: 236.0, nameRot: -3.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="url(#iceG)" stroke="#0A2'
      'A3D" stroke-width="1" d="M84 212 C 134 208 220 200 280 193 C 290 1'
      '92 296 195 294 201 L284 250 L108 250 C 95 242 87 228 84 212 Z"/> <'
      'path fill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke-widt'
      'h="1" stroke-linecap="round" stroke-linejoin="round" d="M88 216 C '
      '140 211.5 226 203.5 292 196"/> <path fill="#0B2236" fill-opacity="'
      '0.88" stroke="#35607C" stroke-width="0.8" d="M130 219 C 170 215.5 '
      '210 212 244 208 L242 216 C 210 219.5 172 223 132 226 Z"/> <path fi'
      'll="none" stroke="#27506B" stroke-width="3" stroke-linecap="round"'
      ' d="M98 245 L283 245"/> <path fill="#D8E9F5" stroke="#0A2A3D" stro'
      'ke-width="1" d="M118 210 L118 178 C 118 173.5 122 170.5 128 170.5 '
      'L206 167 C 224 167 240 175 254 192 L252 196 C 206 201 152 206 122 '
      '210 Z"/> <path fill="#0B2236" fill-opacity="0.88" stroke="#35607C"'
      ' stroke-width="0.8" d="M127 180 L202 176 C 215 176 227 182 238 192'
      ' L130 197 Z"/> <path fill="#C9DEEE" stroke="#0A2A3D" stroke-width='
      '"1" d="M138 170 L140 146 C 140 142 143 139.5 148 139.5 L196 138 C '
      '206 138 214 143 221 153 L223 165 Z"/> <path fill="#0B2236" fill-op'
      'acity="0.88" stroke="#35607C" stroke-width="0.8" d="M147 148 L194 '
      '145.6 L200 155 L149 157 Z"/> <path fill="none" stroke="#EAF6FC" st'
      'roke-opacity="0.75" stroke-width="1" stroke-linecap="round" d="M22'
      '5 196 L225 189 M248 193 L248 186 M270 190 L270 183 M225 189 C 244 '
      '186.5 262 184.5 284 183 M284 190 L284 183"/> <path fill="none" str'
      'oke="#FFFFFF" stroke-opacity="0.4" stroke-width="1.6" stroke-dasha'
      'rray="7 5" d="M60 252 L332 252"/> <path fill="none" stroke="#FFFFF'
      'F" stroke-opacity="0.3" stroke-width="2" stroke-linecap="round" d='
      '"M56 262 Q 76 258 96 262 T 136 262 T 176 262 T 216 262 T 256 262 T'
      ' 296 262 T 334 262"/> <path fill="none" stroke="#FFFFFF" stroke-op'
      'acity="0.14" stroke-width="2" stroke-linecap="round" d="M70 274 Q '
      '90 270 110 274 T 150 274 T 190 274 T 230 274 T 270 274 T 310 274"/'
      '>',
  ),
  'catamaran': BoatArtEntry(
    id: 'catamaran',
    title: 'Katamaran — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 52, vbY: 40, vbW: 296, vbH: 250,
    nameX: 128.0, nameY: 233.0, nameRot: -1.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="none" stroke="#EAF6FC" s'
      'troke-opacity="0.65" stroke-width="1.1" stroke-linecap="round" d="'
      'M206 52 L288 188 M206 52 L112 184"/> <path fill="#F0F7FD" fill-opa'
      'city="0.96" stroke="#9FBBCD" stroke-width="1" d="M202 58 C 196 100'
      ' 184 142 148 170 L202 170 Z"/> <path fill="none" stroke="#0A2A3D" '
      'stroke-opacity="0.28" stroke-width="1" stroke-linecap="round" d="M'
      '192 104 L201 104 M184 136 L201 136 M170 158 L201 158"/> <path fill'
      '="#E2EEF8" fill-opacity="0.88" stroke="#9FBBCD" stroke-width="1" d'
      '="M210 60 C 228 100 252 152 272 182 L240 178 C 234 132 222 96 210 '
      '60 Z"/> <path fill="none" stroke="#B9D2E2" stroke-width="3" stroke'
      '-linecap="round" d="M204 172 L204 50"/> <path fill="none" stroke="'
      '#B9D2E2" stroke-width="3" stroke-linecap="round" d="M204 171 L148 '
      '172"/> <path fill="#D8E9F5" stroke="#0A2A3D" stroke-width="1" d="M'
      '122 198 L124 178 C 124 172.5 129 169 136 168.5 L218 168 C 234 168 '
      '246 173.5 254 184 L257 198 Z"/> <path fill="#0B2236" fill-opacity='
      '"0.88" stroke="#35607C" stroke-width="0.8" d="M132 191 L133 174.5 '
      'L160 173.8 L160 191 Z"/> <path fill="#0B2236" fill-opacity="0.88" '
      'stroke="#35607C" stroke-width="0.8" d="M167 191 L167 173.6 L200 17'
      '3 L200 191 Z"/> <path fill="#0B2236" fill-opacity="0.88" stroke="#'
      '35607C" stroke-width="0.8" d="M207 191 L207 173 L228 172.8 C 237 1'
      '72.8 243 177 247 184 L249 191 Z"/> <path fill="none" stroke="#0A2A'
      '3D" stroke-opacity="0.5" stroke-width="1" stroke-linecap="round" s'
      'troke-linejoin="round" d="M257 194 L292 191"/> <path fill="none" s'
      'troke="#0A2A3D" stroke-opacity="0.28" stroke-width="1" stroke-line'
      'cap="round" d="M261 194.4 L266 198.4 M270 193.8 L275 197.8 M279 19'
      '3.2 L284 197.2"/> <path fill="url(#iceG)" stroke="#0A2A3D" stroke-'
      'width="1" d="M80 202 C 136 199 238 195 292 193.5 L298 242 C 254 25'
      '0.5 144 251.5 102 247 C 90 239 82 221 80 202 Z"/> <path fill="#0B2'
      '236" fill-opacity="0.88" stroke="#35607C" stroke-width="0.8" d="M9'
      '8 199.4 L284 195 L284 200.2 L100 204.6 Z"/> <path fill="#C9DEEE" s'
      'troke="#0A2A3D" stroke-width="1" d="M120 198.8 L123 204.2 L133 204'
      ' L130 198.6 Z M240 195.4 L243 200.8 L253 200.6 L250 195.2 Z"/> <re'
      'ct fill="#0B2236" fill-opacity="0.88" stroke="#35607C" stroke-widt'
      'h="0.8" x="152" y="216" width="28" height="6" rx="3"/> <rect fill='
      '"#0B2236" fill-opacity="0.88" stroke="#35607C" stroke-width="0.8" '
      'x="192" y="214.5" width="28" height="6" rx="3"/> <path fill="none"'
      ' stroke="#27506B" stroke-width="3" stroke-linecap="round" d="M92 2'
      '44 C 150 249 250 247.5 296 240"/> <path fill="none" stroke="#FFFFF'
      'F" stroke-opacity="0.4" stroke-width="1.6" stroke-dasharray="7 5" '
      'd="M60 252 L344 252"/> <path fill="none" stroke="#FFFFFF" stroke-o'
      'pacity="0.3" stroke-width="2" stroke-linecap="round" d="M56 262 Q '
      '76 258 96 262 T 136 262 T 176 262 T 216 262 T 256 262 T 296 262 T '
      '336 262"/> <path fill="none" stroke="#FFFFFF" stroke-opacity="0.14'
      '" stroke-width="2" stroke-linecap="round" d="M70 274 Q 90 270 110 '
      '274 T 150 274 T 190 274 T 230 274 T 270 274 T 310 274"/>',
  ),
  'gulet_std': BoatArtEntry(
    id: 'gulet_std',
    title: 'Gulet ~18 m — tür/boy',
    families: <String>[],
    numbers: <String>[],
    vbX: 42, vbY: 30, vbW: 300, vbH: 260,
    nameX: 122.0, nameY: 239.0, nameRot: 2.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="none" stroke="#EAF6FC" s'
      'troke-opacity="0.65" stroke-width="1.1" stroke-linecap="round" d="'
      'M150 44 L208 206 M150 44 L92 212 M232 70 L272 204 M232 70 L192 206'
      '"/> <path fill="none" stroke="#B9D2E2" stroke-width="3" stroke-lin'
      'ecap="round" d="M150 210 L150 42"/> <path fill="none" stroke="#B9D'
      '2E2" stroke-width="3" stroke-linecap="round" d="M232 206 L232 68"/'
      '> <path fill="none" stroke="#B9D2E2" stroke-width="3" stroke-linec'
      'ap="round" d="M288 198 L322 186"/> <path fill="url(#iceG)" stroke='
      '"#0A2A3D" stroke-width="1" d="M74 214 C 120 222 190 223 250 216 C '
      '266 214 280 209 292 201 L278 250 L102 250 C 90 242 80 229 74 214 Z'
      '"/> <path fill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke'
      '-width="1" stroke-linecap="round" stroke-linejoin="round" d="M80 2'
      '20 C 126 227 192 228 248 221 C 263 219 276 214.5 287 207"/> <path '
      'fill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke-width="1"'
      ' stroke-linecap="round" stroke-linejoin="round" d="M83 225 C 128 2'
      '32 192 233 246 226 C 261 224 273 219.5 284 212"/> <path fill="#D8E'
      '9F5" stroke="#0A2A3D" stroke-width="1" d="M128 219 L128 203 C 128 '
      '200 130 198 134 198 L196 197 L200 217 Z"/> <rect fill="#0B2236" fi'
      'll-opacity="0.88" stroke="#35607C" stroke-width="0.8" x="136" y="2'
      '03.5" width="22" height="6" rx="2.6"/> <rect fill="#0B2236" fill-o'
      'pacity="0.88" stroke="#35607C" stroke-width="0.8" x="166" y="203" '
      'width="22" height="6" rx="2.6"/> <path fill="none" stroke="#27506B'
      '" stroke-width="3" stroke-linecap="round" d="M96 246 L277 246"/> <'
      'path fill="none" stroke="#FFFFFF" stroke-opacity="0.4" stroke-widt'
      'h="1.6" stroke-dasharray="7 5" d="M50 252 L336 252"/> <path fill="'
      'none" stroke="#FFFFFF" stroke-opacity="0.3" stroke-width="2" strok'
      'e-linecap="round" d="M46 262 Q 66 258 86 262 T 126 262 T 166 262 T'
      ' 206 262 T 246 262 T 286 262 T 326 262"/> <path fill="none" stroke'
      '="#FFFFFF" stroke-opacity="0.14" stroke-width="2" stroke-linecap="'
      'round" d="M60 274 Q 80 270 100 274 T 140 274 T 180 274 T 220 274 T'
      ' 260 274 T 300 274"/>',
  ),
  'gulet_buyuk': BoatArtEntry(
    id: 'gulet_buyuk',
    title: 'Gulet ~24 m — tür/boy',
    families: <String>[],
    numbers: <String>[],
    vbX: 28, vbY: 16, vbW: 328, vbH: 274,
    nameX: 104.0, nameY: 238.0, nameRot: 2.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="none" stroke="#EAF6FC" s'
      'troke-opacity="0.65" stroke-width="1.1" stroke-linecap="round" d="'
      'M136 30 L204 204 M136 30 L74 212 M226 52 L284 202 M226 52 L178 206'
      '"/> <path fill="none" stroke="#B9D2E2" stroke-width="3" stroke-lin'
      'ecap="round" d="M136 210 L136 28"/> <path fill="none" stroke="#B9D'
      '2E2" stroke-width="3" stroke-linecap="round" d="M226 204 L226 50"/'
      '> <path fill="none" stroke="#B9D2E2" stroke-width="3" stroke-linec'
      'ap="round" d="M296 196 L336 182"/> <path fill="url(#iceG)" stroke='
      '"#0A2A3D" stroke-width="1" d="M56 212 C 110 221 196 223 262 215 C '
      '280 212.5 294 207 304 199 L290 250 L86 250 C 72 241 62 228 56 212 '
      'Z"/> <path fill="none" stroke="#0A2A3D" stroke-opacity="0.5" strok'
      'e-width="1" stroke-linecap="round" stroke-linejoin="round" d="M62 '
      '218 C 116 226 198 228 260 220 C 277 218 290 213 300 205"/> <path f'
      'ill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke-width="1" '
      'stroke-linecap="round" stroke-linejoin="round" d="M65 223 C 118 23'
      '1 198 233 258 225 C 274 223 287 218 297 210"/> <path fill="#D8E9F5'
      '" stroke="#0A2A3D" stroke-width="1" d="M106 218 L106 200 C 106 197'
      ' 108 195 112 195 L196 193.5 L200 215 Z"/> <rect fill="#0B2236" fil'
      'l-opacity="0.88" stroke="#35607C" stroke-width="0.8" x="114" y="20'
      '0.5" width="24" height="6.2" rx="2.8"/> <rect fill="#0B2236" fill-'
      'opacity="0.88" stroke="#35607C" stroke-width="0.8" x="146" y="200"'
      ' width="24" height="6.2" rx="2.8"/> <rect fill="#0B2236" fill-opac'
      'ity="0.88" stroke="#35607C" stroke-width="0.8" x="178" y="199.5" w'
      'idth="16" height="6.2" rx="2.8"/> <path fill="none" stroke="#27506'
      'B" stroke-width="3" stroke-linecap="round" d="M80 246 L289 246"/> '
      '<path fill="none" stroke="#FFFFFF" stroke-opacity="0.4" stroke-wid'
      'th="1.6" stroke-dasharray="7 5" d="M36 252 L350 252"/> <path fill='
      '"none" stroke="#FFFFFF" stroke-opacity="0.3" stroke-width="2" stro'
      'ke-linecap="round" d="M32 262 Q 52 258 72 262 T 112 262 T 152 262 '
      'T 192 262 T 232 262 T 272 262 T 312 262 T 352 262"/> <path fill="n'
      'one" stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="2" strok'
      'e-linecap="round" d="M46 274 Q 66 270 86 274 T 126 274 T 166 274 T'
      ' 206 274 T 246 274 T 286 274 T 326 274"/>',
  ),
  'daily': BoatArtEntry(
    id: 'daily',
    title: 'Sürat / günlük — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 70, vbY: 156, vbW: 240, vbH: 134,
    nameX: 152.0, nameY: 234.0, nameRot: -2.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="url(#iceG)" stroke="#0A2'
      'A3D" stroke-width="1" d="M114 214 C 154 209 224 202 262 199 C 274 '
      '198 280 201 278 207 L269 246 L126 246 C 116 238 112 226 114 214 Z"'
      '/> <path fill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke-'
      'width="1" stroke-linecap="round" stroke-linejoin="round" d="M118 2'
      '18 C 160 213 230 206 276 202"/> <path fill="none" stroke="#27506B"'
      ' stroke-width="3" stroke-linecap="round" d="M122 242 L267 242"/> <'
      'path fill="#D8E9F5" stroke="#0A2A3D" stroke-width="1" d="M180 210 '
      'L184 186 L206 185 L215 207 Z"/> <path fill="#0B2236" fill-opacity='
      '"0.88" stroke="#35607C" stroke-width="0.8" d="M187 188.5 L204 187.'
      '5 L210 199 L189 200.5 Z"/> <path fill="none" stroke="#EAF6FC" stro'
      'ke-opacity="0.75" stroke-width="1" stroke-linecap="round" d="M224 '
      '208 L224 199 M242 206 L242 197 M258 204 L258 195 M224 199 C 238 19'
      '7 252 195.6 266 194.6 M266 202.6 L266 194.6"/> <path fill="#C9DEEE'
      '" stroke="#0A2A3D" stroke-width="1" d="M102 218 C 102 213 105.5 21'
      '0 110 210 L120 210 L121 231 L111 231 L111 241 L104 241 Z"/> <path '
      'fill="#9CC0D6" stroke="#0A2A3D" stroke-width="1" d="M105 241 L111 '
      '241 L111 252 L105 252 Z"/> <path fill="none" stroke="#FFFFFF" stro'
      'ke-opacity="0.4" stroke-width="1.6" stroke-dasharray="7 5" d="M78 '
      '252 L302 252"/> <path fill="none" stroke="#FFFFFF" stroke-opacity='
      '"0.3" stroke-width="2" stroke-linecap="round" d="M74 262 Q 94 258 '
      '114 262 T 154 262 T 194 262 T 234 262 T 274 262 T 304 262"/> <path'
      ' fill="none" stroke="#FFFFFF" stroke-opacity="0.14" stroke-width="'
      '2" stroke-linecap="round" d="M88 274 Q 108 270 128 274 T 168 274 T'
      ' 208 274 T 248 274 T 288 274"/>',
  ),
  'fishing': BoatArtEntry(
    id: 'fishing',
    title: 'Balıkçı — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 60, vbY: 118, vbW: 252, vbH: 172,
    nameX: 150.0, nameY: 238.0, nameRot: 2.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="url(#iceG)" stroke="#0A2'
      'A3D" stroke-width="1" d="M98 208 C 132 216 186 219 228 215 C 248 2'
      '13 266 206 280 194 L268 248 L122 248 C 110 239 101 225 98 208 Z"/>'
      ' <path fill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke-wi'
      'dth="1" stroke-linecap="round" stroke-linejoin="round" d="M103 214'
      ' C 138 221.5 190 224.5 228 220.5 C 246 218.5 262 212 275 201"/> <p'
      'ath fill="#D8E9F5" stroke="#0A2A3D" stroke-width="1" d="M126 216 L'
      '126 180 C 126 176.5 128.5 174 132 174 L158 173 L166 214 Z"/> <rect'
      ' fill="#0B2236" fill-opacity="0.88" stroke="#35607C" stroke-width='
      '"0.8" x="133" y="181" width="20" height="9" rx="2.6"/> <path fill='
      '"none" stroke="#B9D2E2" stroke-width="3" stroke-linecap="round" d='
      '"M198 212 L198 134"/> <path fill="none" stroke="#0A2A3D" stroke-op'
      'acity="0.5" stroke-width="1" stroke-linecap="round" stroke-linejoi'
      'n="round" d="M199 148 L240 190"/> <path fill="none" stroke="#0A2A3'
      'D" stroke-opacity="0.28" stroke-width="1" stroke-linecap="round" d'
      '="M198 148 L176 196"/> <circle cx="198" cy="130" r="3" fill="#F8C5'
      '60" stroke="#0A2A3D" stroke-width="0.8"/> <path fill="none" stroke'
      '="#27506B" stroke-width="3" stroke-linecap="round" d="M116 244 L26'
      '7 244"/> <path fill="none" stroke="#FFFFFF" stroke-opacity="0.4" s'
      'troke-width="1.6" stroke-dasharray="7 5" d="M68 252 L304 252"/> <p'
      'ath fill="none" stroke="#FFFFFF" stroke-opacity="0.3" stroke-width'
      '="2" stroke-linecap="round" d="M64 262 Q 84 258 104 262 T 144 262 '
      'T 184 262 T 224 262 T 264 262 T 302 262"/> <path fill="none" strok'
      'e="#FFFFFF" stroke-opacity="0.14" stroke-width="2" stroke-linecap='
      '"round" d="M78 274 Q 98 270 118 274 T 158 274 T 198 274 T 238 274 '
      'T 278 274"/>',
  ),
  'rib': BoatArtEntry(
    id: 'rib',
    title: 'RIB / şişme — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 72, vbY: 150, vbW: 232, vbH: 140,
    nameX: 158.0, nameY: 232.0, nameRot: -1.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="#C9DEEE" stroke="#0A2A3D'
      '" stroke-width="1" d="M116 212 C 116 204 122 199 131 199 L218 196 '
      'C 232 195.5 246 191 258 183 C 263 180 268 178.5 272 179 C 275 186 '
      '272 196 264 204 C 255 213 240 217 224 217.5 L128 219 C 120 219 116'
      ' 217 116 212 Z"/> <path fill="none" stroke="#0A2A3D" stroke-opacit'
      'y="0.5" stroke-width="1" stroke-linecap="round" stroke-linejoin="r'
      'ound" d="M146 199.5 L146 218.4 M172 198.6 L172 217.6 M198 197.6 L1'
      '98 216.8 M224 196.4 L224 217"/> <path fill="url(#iceG)" stroke="#0'
      'A2A3D" stroke-width="1" d="M128 219 L240 216.5 L230 240 L146 240 Z'
      '"/> <path fill="#D8E9F5" stroke="#0A2A3D" stroke-width="1" d="M178'
      ' 198 L181 176 L201 175 L208 195.5 Z"/> <path fill="#0B2236" fill-o'
      'pacity="0.88" stroke="#35607C" stroke-width="0.8" d="M184 178.5 L1'
      '99 177.5 L204 188 L186 189.5 Z"/> <path fill="#C9DEEE" stroke="#0A'
      '2A3D" stroke-width="1" d="M156 200 L156 186 L168 185.5 L170 199 Z"'
      '/> <path fill="#C9DEEE" stroke="#0A2A3D" stroke-width="1" d="M102 '
      '206 C 102 201 105.5 198 110 198 L118 198 L119 220 L109 220 L109 23'
      '0 L102 230 Z"/> <path fill="#9CC0D6" stroke="#0A2A3D" stroke-width'
      '="1" d="M103 230 L109 230 L109 246 L103 246 Z"/> <path fill="none"'
      ' stroke="#FFFFFF" stroke-opacity="0.4" stroke-width="1.6" stroke-d'
      'asharray="7 5" d="M80 252 L296 252"/> <path fill="none" stroke="#F'
      'FFFFF" stroke-opacity="0.3" stroke-width="2" stroke-linecap="round'
      '" d="M76 262 Q 96 258 116 262 T 156 262 T 196 262 T 236 262 T 276 '
      '262 T 298 262"/> <path fill="none" stroke="#FFFFFF" stroke-opacity'
      '="0.14" stroke-width="2" stroke-linecap="round" d="M90 274 Q 110 2'
      '70 130 274 T 170 274 T 210 274 T 250 274 T 290 274"/>',
  ),
  'super': BoatArtEntry(
    id: 'super',
    title: 'Süperyat — genel tür',
    families: <String>[],
    numbers: <String>[],
    vbX: 28, vbY: 78, vbW: 332, vbH: 212,
    nameX: 104.0, nameY: 232.0, nameRot: -3.0,
    svgBody: '<defs><linearGradient id="iceG" x1="0" y1="0" x2="0" y2="1"><stop '
      'offset="0" stop-color="#F4FAFF"/><stop offset="1" stop-color="#BBD'
      '8EB"/></linearGradient></defs><path fill="url(#iceG)" stroke="#0A2'
      'A3D" stroke-width="1" d="M54 206 C 120 202 230 194 300 187 C 312 1'
      '86 320 189 318 196 L306 250 L80 250 C 66 242 57 226 54 206 Z"/> <p'
      'ath fill="none" stroke="#0A2A3D" stroke-opacity="0.5" stroke-width'
      '="1" stroke-linecap="round" stroke-linejoin="round" d="M58 210 C 1'
      '26 205.5 236 197.5 316 190"/> <path fill="#0B2236" fill-opacity="0'
      '.88" stroke="#35607C" stroke-width="0.8" d="M96 216 C 160 211 240 '
      '204 286 199 L284 208 C 240 212.5 162 219.5 98 224 Z"/> <path fill='
      '"none" stroke="#27506B" stroke-width="3" stroke-linecap="round" d='
      '"M70 245 L305 245"/> <path fill="#D8E9F5" stroke="#0A2A3D" stroke-'
      'width="1" d="M86 204 L86 172 C 86 167.5 90 164.5 96 164.5 L212 160'
      ' C 234 160 254 169 272 188 L270 192 C 204 198 130 203 90 206 Z"/> '
      '<path fill="#0B2236" fill-opacity="0.88" stroke="#35607C" stroke-w'
      'idth="0.8" d="M96 174 L208 169 C 224 169 240 176 254 188 L98 194 Z'
      '"/> <path fill="#C9DEEE" stroke="#0A2A3D" stroke-width="1" d="M106'
      ' 164 L108 136 C 108 131.5 112 128.5 118 128.5 L196 126 C 210 126 2'
      '22 132 231 145 L233 158 Z"/> <path fill="#0B2236" fill-opacity="0.'
      '88" stroke="#35607C" stroke-width="0.8" d="M116 138 L194 134.5 L20'
      '1 147 L118 150.5 Z"/> <path fill="#C9DEEE" stroke="#0A2A3D" stroke'
      '-width="1" d="M130 128 L132 108 C 132 104 135 101.5 140 101.5 L178'
      ' 100 C 188 100 196 105 202 115 L204 124 Z"/> <path fill="#0B2236" '
      'fill-opacity="0.88" stroke="#35607C" stroke-width="0.8" d="M139 10'
      '9.5 L177 107.5 L182 117 L141 119 Z"/> <path fill="none" stroke="#7'
      'E9DB2" stroke-width="1" stroke-linecap="round" d="M188 100 L185 88'
      ' M181 88 L191 88"/> <path fill="none" stroke="#EAF6FC" stroke-opac'
      'ity="0.75" stroke-width="1" stroke-linecap="round" d="M238 192 L23'
      '8 185 M262 189.4 L262 182.4 M286 186.6 L286 179.6 M238 185 C 258 1'
      '82.5 276 180.5 298 179 M298 186 L298 179"/> <path fill="none" stro'
      'ke="#FFFFFF" stroke-opacity="0.4" stroke-width="1.6" stroke-dashar'
      'ray="7 5" d="M36 252 L352 252"/> <path fill="none" stroke="#FFFFFF'
      '" stroke-opacity="0.3" stroke-width="2" stroke-linecap="round" d="'
      'M32 262 Q 52 258 72 262 T 112 262 T 152 262 T 192 262 T 232 262 T '
      '272 262 T 312 262 T 352 262"/> <path fill="none" stroke="#FFFFFF" '
      'stroke-opacity="0.14" stroke-width="2" stroke-linecap="round" d="M'
      '46 274 Q 66 270 86 274 T 126 274 T 166 274 T 206 274 T 246 274 T 2'
      '86 274 T 326 274"/>',
  ),
};
