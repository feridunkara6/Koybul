/// AKADEMİ İÇERİĞİ (v2.0 "Akademi lite", kurucu onayı 2026-08).
///
/// 10 kısa rehber, DÖRT dilde. Metinler bu uygulama için yazılmıştır —
/// hiçbir kılavuz kitaptan/siteden alıntı veya çeviri değildir. İçerik genel
/// denizcilik uygulamasıdır; resmî eğitim, sertifikasyon ve güncel seyir
/// yayınlarının yerine geçmez (her rehberin altında bu not gösterilir).
///
/// YAPI: kimlik + ikon TEK yerde ([_topics]); metinler dil sözlüklerinde.
/// Böylece her dilde AYNI 10 rehber garanti olur (test bunu doğrular).
library;

import 'package:dockly_ui/dockly_ui.dart';

import '../../../core/l10n/app_locale.dart';
import '../domain/guide.dart';

/// Rehber kimliği + ikonu (dilden bağımsız, sıra listede görünen sıradır).
class _Topic {
  const _Topic(this.id, this.icon);
  final String id;
  final DocklyIconData icon;
}

const List<_Topic> _topics = <_Topic>[
  _Topic('anchor', DocklyIcons.amMooring),
  _Topic('quay', DocklyIcons.place),
  _Topic('wind', DocklyIcons.explore),
  _Topic('forecast', DocklyIcons.infoOutline),
  _Topic('rules', DocklyIcons.navigation),
  _Topic('lights', DocklyIcons.star),
  _Topic('vhf', DocklyIcons.radio),
  _Topic('mayday', DocklyIcons.errorOutline),
  _Topic('mob', DocklyIcons.helpOutline),
  _Topic('predeparture', DocklyIcons.checkCircle),
];

/// Rehber sayısı — arayüz ve testler bu sabiti okur. ([_topics].length bir
/// derleme-zamanı sabiti DEĞİLDİR; sayı elle tutulur, test eşitliği doğrular.)
const int kAcademyGuideCount = 10;

/// Seçili dildeki rehber listesi. Bir metin eksikse o rehber ATLANMAZ,
/// İngilizcesi gösterilir (dürüst yedek: kullanıcı boş ekran görmez).
List<Guide> academyGuides(AppLocale locale) {
  final Map<String, GuideText> table = _tableOf(locale);
  final List<Guide> out = <Guide>[];
  for (final _Topic t in _topics) {
    final GuideText? g = table[t.id] ?? _en[t.id];
    if (g == null) continue;
    out.add(Guide(
      id: t.id,
      icon: t.icon,
      title: g.title,
      summary: g.summary,
      points: g.points,
      note: g.note,
    ));
  }
  return out;
}

/// Tek rehberi kimliğiyle getirir (bağlam kancaları için) — yoksa null.
Guide? academyGuideById(AppLocale locale, String id) {
  for (final Guide g in academyGuides(locale)) {
    if (g.id == id) return g;
  }
  return null;
}

Map<String, GuideText> _tableOf(AppLocale locale) {
  switch (locale) {
    case AppLocale.tr:
      return _tr;
    case AppLocale.en:
      return _en;
    case AppLocale.es:
      return _es;
    case AppLocale.ru:
      return _ru;
  }
}

// ---------------------------------------------------------------- TÜRKÇE

const Map<String, GuideText> _tr = <String, GuideText>{
  'anchor': GuideText(
    title: 'Demir atma',
    summary: 'Sağlam tutan bir demir, huzurlu bir gece demektir.',
    points: <String>[
      'Koya girerken hızını kes; derinliği, zemini ve rüzgârın geleceği yönü kontrol et.',
      'Zincir boyu kuraldır: sakin havada derinliğin en az 4 katı, sert havada 6–7 katı.',
      'Demiri bırak ve tekne geriye kayarken zinciri yavaşça sal — hepsini tek yığın hâlinde bırakma.',
      'Zincir gerilince makineyle hafifçe geri tut; tekne durup zincir titremiyorsa demir tutmuştur.',
      'Kıyıya ve komşu teknelere salınım yarıçapın kadar mesafe bırak; gece rüzgâr dönebilir.',
    ],
    note: 'Tuttuğuna emin olmadan motoru kapatma. Karada iki referans noktası seç; '
        'gece bunlar kaydıysa demir tarıyor demektir.',
  ),
  'quay': GuideText(
    title: 'Rıhtıma kıçtan bağlanma',
    summary: 'Akdeniz usulü bağlama, hazırlık ve sakinlikle kolaylaşır.',
    points: <String>[
      'Manevradan önce halatları ve usturmaçaları hazırla, görev dağılımını yap.',
      'Rüzgârın hangi taraftan bastığını belirle; yaklaşmayı rüzgâra karşı planla.',
      'Demiri yeterince açıkta bırak — kabaca tekne boyunun 4–5 katı mesafede — ve yavaşça geri gel.',
      'Kıç halatlarını verdikten sonra demir zincirini gererek tekneyi rıhtımdan uzak tut.',
    ],
    note: 'Acele etme: başarısız bir yanaşmayı tekrarlamak, zorlamaktan her zaman ucuzdur.',
  ),
  'wind': GuideText(
    title: 'Bölge rüzgârlarını tanı',
    summary: 'Rüzgârın adı, karakterini de söyler.',
    points: <String>[
      'Meltem yaz aylarında öğleden sonra kuvvetlenir, akşama doğru düşer; günü buna göre planla.',
      'Poyraz (kuzeydoğu) kuru ve serttir; lodos (güneybatı) nemlidir ve genellikle dalga getirir.',
      'Koy seçerken rüzgârın estiği yöne açık olanları ele; korunaklı taraf kara tarafıdır.',
      'Sabahın erken saatleri genelde en sakin dilimdir — uzun geçişleri oraya al.',
    ],
    note: 'Dağ boğazları ve burun geçişleri rüzgârı yerel olarak katlayabilir; '
        'tahmin bölgeyi anlatır, koyu değil.',
  ),
  'forecast': GuideText(
    title: 'Hava tahminini okumak',
    summary: 'Tek sayıya değil, eğilime bak.',
    points: <String>[
      'Rüzgâr hızını hamleyle birlikte oku; hamleler ortalamanın belirgin şekilde üstüne çıkabilir.',
      'Yön değişimi hız kadar önemlidir: rüzgâr dönerse korunaklı koyun gece açık koya dönüşebilir.',
      'Birden fazla kaynağa bak; kaynaklar ayrışıyorsa belirsizlik yüksektir, planı esnek tut.',
      'İki günden uzak tahminler hızla güvenilirliğini yitirir; planı her sabah tazele.',
    ],
    note: 'Resmî meteoroloji uyarıları her zaman önceliklidir.',
  ),
  'rules': GuideText(
    title: 'Denizde yol verme',
    summary: 'Kim kime yol verir — birkaç sade kural.',
    points: <String>[
      'Motorlu tekne, yelkenle seyreden tekneye yol verir; ancak dar kanalda büyük gemi manevra edemez, açılan sen olursun.',
      'İki yelkenli karşılaşırsa rüzgârı sancaktan alan tekne yol hakkına sahiptir.',
      'İki motorlu tekne baş başa geliyorsa her ikisi de sancağa döner.',
      'Yol hakkın olsa bile çarpışmayı önlemekle yükümlüsün — kural, kaza gerekçesi değildir.',
    ],
    note: 'Niyetini erken ve belirgin göster; küçük düzeltmeleri karşı tekne fark etmez.',
  ),
  'lights': GuideText(
    title: 'Gece seyri ve fenerler',
    summary: 'Karanlıkta gördüğün ışık, teknenin yönünü anlatır.',
    points: <String>[
      'Sancak yeşil, iskele kırmızı, kıç beyazdır; iki rengi birden görüyorsan tekne sana doğru geliyordur.',
      'Demirli tekne tek beyaz fener gösterir — koya gece girerken önce bunları ara.',
      'Gece görüşünü koru: güverte ve ekran ışıklarını kıs, el fenerini kırmızı moda al.',
      'Gündüz görmediğin bir koya gece girme; bilinmeyen su karanlıkta iki kat dardır.',
    ],
  ),
  'vhf': GuideText(
    title: 'VHF telsiz ve 16. kanal',
    summary: 'Telsiz, denizdeki ortak dildir.',
    points: <String>[
      'Kanal 16 dinleme ve acil çağrı kanalıdır; görüşmeyi bir çalışma kanalına taşı.',
      'Konuşmadan önce dinle. Çağrı düzeni: karşı istasyonun adı iki kez, kendi adın bir kez.',
      'Kısa ve net konuş; cümleni bitirince "tamam" diyerek sırayı karşıya devret.',
      'Marina ve liman kanalları farklıdır; yaklaşmadan önce doğru kanalı öğren.',
    ],
    note: 'Seyirde telsizini açık tut — imdadını ilk duyacak olan, yakınındaki tekne olabilir.',
  ),
  'mayday': GuideText(
    title: 'Acil çağrı: MAYDAY',
    summary: 'Hayati tehlike varsa tereddüt etme.',
    points: <String>[
      'Kanal 16\'da üç kez "MAYDAY"; ardından tekne adı, konum, tehlikenin ne olduğu, kişi sayısı ve istenen yardım.',
      'Konumu enlem-boylam ver; mümkünse en yakın belirgin noktaya göre de tarif et.',
      'Telsizinde DSC düğmesi varsa önce onu kullan: kimliği ve konumu otomatik iletir.',
      'Hayati tehlike yok ama yardım gerekiyorsa çağrı "PAN PAN" ile yapılır.',
    ],
    note: 'Türkiye kıyılarında Sahil Güvenlik acil numarası 158\'dir; '
        'uygulamadaki Acil sayfasında tek dokunuşla ararsın.',
  ),
  'mob': GuideText(
    title: 'Denize adam düştü',
    summary: 'İlk otuz saniye her şeyi belirler.',
    points: <String>[
      'Yüksek sesle "Denize adam düştü!" de. Bir kişi yalnızca kazazedeyi göstermekle görevlendirilir ve gözünü ayırmaz.',
      'MOB düğmesine bas ya da konumu işaretle; can simidini hemen suya at.',
      'Motor kullanacaksan pervaneye dikkat et; kazazedeye rüzgârın üstünden, kontrollü yaklaş.',
      'Sudan alma planını önceden konuş: merdiven, halat, yelken bezi. Yorgun bir insanı çıkarmak sanılandan zordur.',
    ],
    note: 'Bu manevrayı sakin bir günde bir şamandırayla prova et — ilk denemen acil durumda olmasın.',
  ),
  'predeparture': GuideText(
    title: 'Kalkıştan önce tekne kontrolü',
    summary: 'Beş dakikalık kontrol, saatlerce huzur.',
    points: <String>[
      'Motor: yağ ve soğutma suyu seviyesi, kayış, deniz suyu vanası açık mı — çalıştırınca egzozdan su geliyor mu?',
      'Sintine kuru ve pompa çalışır durumda mı? Yakıt yeterli mi (üçte bir kuralı: gidiş, dönüş, yedek)?',
      'Güverte: halatlar toplu, usturmaçalar yerinde, ıskotalar serbest mi?',
      'Can yelekleri, ilk yardım çantası ve el feneri yerinde ve herkesin erişebileceği yerde mi?',
    ],
    note: 'Kalkış öncesi maddeleri uygulamadaki kontrol listesinden tek tek işaretleyebilirsin.',
  ),
};

// --------------------------------------------------------------- ENGLISH

const Map<String, GuideText> _en = <String, GuideText>{
  'anchor': GuideText(
    title: 'Anchoring',
    summary: 'An anchor that holds means a peaceful night.',
    points: <String>[
      'Slow down as you enter the bay; check the depth, the seabed and where the wind will come from.',
      'Scope is the rule: at least 4 times the depth in calm weather, 6–7 times when it blows.',
      'Drop the anchor and pay out chain as the boat drifts back — never dump it all in one pile.',
      'When the chain comes taut, back down gently on the engine; if the boat stops and the chain stops juddering, it is set.',
      'Leave your full swinging radius to the shore and to neighbouring boats; the wind can veer overnight.',
    ],
    note: 'Do not shut the engine down until you are sure it holds. Pick two transits ashore; '
        'if they shift during the night, you are dragging.',
  ),
  'quay': GuideText(
    title: 'Stern-to mooring',
    summary: 'Med mooring gets easy with preparation and a calm head.',
    points: <String>[
      'Prepare lines and fenders before the manoeuvre and agree who does what.',
      'Work out which side the wind is pushing from and plan your approach into it.',
      'Drop the anchor far enough out — roughly 4–5 boat lengths — and come astern slowly.',
      'Once the stern lines are ashore, tension the anchor chain to hold the boat off the quay.',
    ],
    note: 'Never rush: repeating a failed approach is always cheaper than forcing one.',
  ),
  'wind': GuideText(
    title: 'Know your local winds',
    summary: 'The name of a wind tells you its character.',
    points: <String>[
      'The meltemi builds through the afternoon in summer and eases towards evening; plan the day around it.',
      'Poyraz (northeast) is dry and hard; lodos (southwest) is humid and usually brings swell.',
      'When choosing a bay, rule out the ones open to the wind direction; shelter is on the land side.',
      'Early morning is usually the calmest slot — put long passages there.',
    ],
    note: 'Mountain gaps and headlands can double the wind locally; a forecast describes the region, not your bay.',
  ),
  'forecast': GuideText(
    title: 'Reading a forecast',
    summary: 'Look at the trend, not a single number.',
    points: <String>[
      'Read wind speed together with gusts; gusts can run well above the average.',
      'A shift in direction matters as much as speed: a sheltered bay can become an exposed one overnight.',
      'Check more than one source; when they disagree, uncertainty is high — keep the plan flexible.',
      'Beyond two days a forecast loses reliability fast; refresh your plan every morning.',
    ],
    note: 'Official meteorological warnings always take precedence.',
  ),
  'rules': GuideText(
    title: 'Right of way at sea',
    summary: 'Who gives way to whom — a few plain rules.',
    points: <String>[
      'A power-driven vessel gives way to a vessel under sail; but in a narrow channel a large ship cannot manoeuvre, so you are the one who moves.',
      'When two sailing boats meet, the one with the wind on its starboard side has right of way.',
      'When two power-driven boats meet head-on, both alter course to starboard.',
      'Even with right of way you must avoid the collision — a rule is never an excuse for an accident.',
    ],
    note: 'Signal your intention early and clearly; small corrections are invisible to the other boat.',
  ),
  'lights': GuideText(
    title: 'Night passage and navigation lights',
    summary: 'The light you see in the dark tells you where a vessel is heading.',
    points: <String>[
      'Starboard is green, port is red, the stern light is white; seeing both colours means the vessel is coming towards you.',
      'A boat at anchor shows a single white light — look for those first when entering a bay at night.',
      'Protect your night vision: dim deck and screen lights, put your torch on red.',
      'Do not enter a bay at night that you have not seen by day; unknown water is twice as narrow in the dark.',
    ],
  ),
  'vhf': GuideText(
    title: 'VHF radio and channel 16',
    summary: 'The radio is the common language at sea.',
    points: <String>[
      'Channel 16 is for listening and distress; move the conversation to a working channel.',
      'Listen before you speak. The call pattern: the other station\'s name twice, your own once.',
      'Keep it short and clear; hand the turn over by saying "over" when you finish.',
      'Marina and port channels differ; find the right one before you approach.',
    ],
    note: 'Keep the radio on while under way — the first to hear you may be the boat next to you.',
  ),
  'mayday': GuideText(
    title: 'Distress call: MAYDAY',
    summary: 'If life is in danger, do not hesitate.',
    points: <String>[
      '"MAYDAY" three times on channel 16, then boat name, position, the nature of the danger, number of people and the help you need.',
      'Give the position in latitude and longitude; add a bearing from the nearest landmark if you can.',
      'If your radio has a DSC button, press it first: it sends your identity and position automatically.',
      'When life is not in danger but you still need help, the call is "PAN PAN".',
    ],
    note: 'On the Turkish coast the Coast Guard emergency number is 158; '
        'the app\'s Emergency page dials it in one tap.',
  ),
  'mob': GuideText(
    title: 'Man overboard',
    summary: 'The first thirty seconds decide everything.',
    points: <String>[
      'Shout "Man overboard!" One crew member does nothing but point at the casualty and never looks away.',
      'Press the MOB button or mark the position; throw the lifebuoy immediately.',
      'If you use the engine, mind the propeller; approach from upwind, under control.',
      'Agree the recovery plan in advance: ladder, line, sail cloth. Lifting a tired person out of the water is harder than it looks.',
    ],
    note: 'Rehearse the manoeuvre with a fender on a calm day — do not let the emergency be your first attempt.',
  ),
  'predeparture': GuideText(
    title: 'Pre-departure boat check',
    summary: 'Five minutes of checks, hours of peace.',
    points: <String>[
      'Engine: oil and coolant levels, belt, seacock open — is water coming out of the exhaust once it runs?',
      'Is the bilge dry and the pump working? Is there enough fuel (the thirds rule: out, back, reserve)?',
      'Deck: lines coiled, fenders in place, sheets running free.',
      'Are lifejackets, first-aid kit and torch stowed where everyone can reach them?',
    ],
    note: 'You can tick the pre-departure items off one by one in the app\'s checklist.',
  ),
};

// --------------------------------------------------------------- ESPAÑOL

const Map<String, GuideText> _es = <String, GuideText>{
  'anchor': GuideText(
    title: 'Fondear',
    summary: 'Un ancla que agarra bien significa una noche tranquila.',
    points: <String>[
      'Reduce la velocidad al entrar en la cala; comprueba la profundidad, el fondo y de dónde vendrá el viento.',
      'La longitud de cadena manda: al menos 4 veces la profundidad con calma, 6–7 veces con viento fuerte.',
      'Suelta el ancla y ve largando cadena mientras el barco cae hacia atrás; nunca la sueltes toda de golpe.',
      'Cuando la cadena trabaje, da atrás suavemente con el motor; si el barco se detiene y la cadena deja de vibrar, ha agarrado.',
      'Deja todo tu radio de borneo hasta la costa y los barcos vecinos; el viento puede rolar de noche.',
    ],
    note: 'No apagues el motor hasta estar seguro de que agarra. Elige dos referencias en tierra: '
        'si de noche se desplazan, estás garreando.',
  ),
  'quay': GuideText(
    title: 'Atraque de popa al muelle',
    summary: 'El amarre a la mediterránea se vuelve fácil con preparación y calma.',
    points: <String>[
      'Prepara cabos y defensas antes de la maniobra y reparte las tareas.',
      'Determina de qué lado empuja el viento y planifica la aproximación contra él.',
      'Fondea con suficiente distancia —unas 4–5 esloras— y ve dando atrás despacio.',
      'Una vez dados los cabos de popa, tensa la cadena del ancla para mantener el barco separado del muelle.',
    ],
    note: 'Sin prisa: repetir una aproximación fallida siempre sale más barato que forzarla.',
  ),
  'wind': GuideText(
    title: 'Conoce los vientos de la zona',
    summary: 'El nombre de un viento ya dice cómo se comporta.',
    points: <String>[
      'El meltemi refuerza por la tarde en verano y afloja al anochecer; planifica el día en consecuencia.',
      'El poyraz (nordeste) es seco y duro; el lodos (suroeste) es húmedo y suele traer mar de fondo.',
      'Al elegir cala, descarta las abiertas a la dirección del viento; el abrigo está del lado de tierra.',
      'Las primeras horas de la mañana suelen ser las más tranquilas: deja ahí las travesías largas.',
    ],
    note: 'Los pasos entre montañas y las puntas pueden duplicar el viento localmente; '
        'la previsión describe la región, no tu cala.',
  ),
  'forecast': GuideText(
    title: 'Leer la previsión',
    summary: 'Mira la tendencia, no un número suelto.',
    points: <String>[
      'Lee la velocidad del viento junto con las rachas; las rachas pueden superar con claridad la media.',
      'El cambio de dirección importa tanto como la fuerza: una cala abrigada puede quedar expuesta de noche.',
      'Consulta más de una fuente; si discrepan, la incertidumbre es alta y conviene un plan flexible.',
      'Más allá de dos días la previsión pierde fiabilidad rápido; actualiza el plan cada mañana.',
    ],
    note: 'Los avisos oficiales de meteorología tienen siempre prioridad.',
  ),
  'rules': GuideText(
    title: 'Preferencia de paso en el mar',
    summary: 'Quién cede el paso a quién: unas reglas sencillas.',
    points: <String>[
      'El barco a motor cede el paso al que navega a vela; pero en un canal estrecho el buque grande no puede maniobrar y quien se aparta eres tú.',
      'Cuando se cruzan dos veleros, tiene preferencia el que recibe el viento por estribor.',
      'Si dos barcos a motor se encuentran de proa, ambos caen a estribor.',
      'Aunque tengas preferencia, estás obligado a evitar el abordaje: una regla nunca justifica un accidente.',
    ],
    note: 'Muestra tu intención pronto y con claridad; las correcciones pequeñas no las ve el otro barco.',
  ),
  'lights': GuideText(
    title: 'Navegación nocturna y luces',
    summary: 'La luz que ves en la oscuridad te dice hacia dónde va el barco.',
    points: <String>[
      'Estribor es verde, babor rojo y la luz de alcance blanca; si ves los dos colores, el barco viene hacia ti.',
      'Un barco fondeado muestra una sola luz blanca: búscalas primero al entrar de noche en una cala.',
      'Cuida tu visión nocturna: baja las luces de cubierta y de pantalla, y usa la linterna en rojo.',
      'No entres de noche en una cala que no hayas visto de día; el agua desconocida es el doble de estrecha a oscuras.',
    ],
  ),
  'vhf': GuideText(
    title: 'La VHF y el canal 16',
    summary: 'La radio es el idioma común en el mar.',
    points: <String>[
      'El canal 16 es de escucha y socorro; pasa la conversación a un canal de trabajo.',
      'Escucha antes de hablar. Patrón de llamada: el nombre de la otra estación dos veces, el tuyo una.',
      'Habla corto y claro; al terminar cede el turno diciendo «cambio».',
      'Los canales de marinas y puertos varían; averigua el correcto antes de aproximarte.',
    ],
    note: 'Mantén la radio encendida en navegación: quien primero te oiga puede ser el barco de al lado.',
  ),
  'mayday': GuideText(
    title: 'Llamada de socorro: MAYDAY',
    summary: 'Si hay peligro para la vida, no dudes.',
    points: <String>[
      '«MAYDAY» tres veces en el canal 16; después nombre del barco, posición, naturaleza del peligro, número de personas y ayuda que necesitas.',
      'Da la posición en latitud y longitud; si puedes, añade la demora desde el punto notable más cercano.',
      'Si tu equipo tiene botón DSC, púlsalo primero: envía identidad y posición automáticamente.',
      'Cuando no hay peligro para la vida pero necesitas ayuda, la llamada es «PAN PAN».',
    ],
    note: 'En la costa turca el número de emergencia de la Guardia Costera es el 158; '
        'la página de Emergencia de la app lo marca con un toque.',
  ),
  'mob': GuideText(
    title: 'Hombre al agua',
    summary: 'Los primeros treinta segundos lo deciden todo.',
    points: <String>[
      'Grita «¡Hombre al agua!». Una persona se dedica solo a señalar a la víctima y no aparta la vista.',
      'Pulsa el botón MOB o marca la posición; lanza el aro salvavidas de inmediato.',
      'Si usas el motor, cuidado con la hélice; aproxímate desde barlovento y con control.',
      'Acuerda antes el plan de recogida: escalera, cabo, vela. Sacar del agua a alguien agotado cuesta más de lo que parece.',
    ],
    note: 'Ensaya la maniobra con una defensa en un día tranquilo: que la emergencia no sea tu primer intento.',
  ),
  'predeparture': GuideText(
    title: 'Revisión antes de salir',
    summary: 'Cinco minutos de comprobaciones, horas de tranquilidad.',
    points: <String>[
      'Motor: nivel de aceite y refrigerante, correa, grifo de fondo abierto. ¿Sale agua por el escape al arrancar?',
      '¿La sentina está seca y la bomba funciona? ¿Hay combustible suficiente (regla de los tercios: ida, vuelta, reserva)?',
      'Cubierta: cabos adujados, defensas colocadas, escotas libres.',
      '¿Chalecos, botiquín y linterna están estibados donde todos puedan alcanzarlos?',
    ],
    note: 'Puedes ir marcando los puntos previos a la salida en la lista de comprobación de la app.',
  ),
};

// --------------------------------------------------------------- РУССКИЙ

const Map<String, GuideText> _ru = <String, GuideText>{
  'anchor': GuideText(
    title: 'Постановка на якорь',
    summary: 'Надёжно забравший якорь — это спокойная ночь.',
    points: <String>[
      'Заходя в бухту, сбавьте ход; проверьте глубину, грунт и с какой стороны придёт ветер.',
      'Длина цепи решает: не менее 4 глубин в тихую погоду и 6–7 при свежем ветре.',
      'Отдайте якорь и травите цепь, пока лодка отходит назад, — не сбрасывайте всё одной кучей.',
      'Когда цепь натянется, мягко подработайте задним ходом: лодка остановилась и цепь не дёргается — якорь забрал.',
      'Оставьте до берега и соседних лодок полный радиус разворота: ночью ветер может зайти.',
    ],
    note: 'Не глушите двигатель, пока не убедились, что якорь держит. Выберите два ориентира на берегу: '
        'если ночью они сместились — вас тащит.',
  ),
  'quay': GuideText(
    title: 'Швартовка кормой к причалу',
    summary: 'Средиземноморская швартовка проста при подготовке и спокойствии.',
    points: <String>[
      'До манёвра приготовьте концы и кранцы, распределите обязанности.',
      'Определите, с какой стороны давит ветер, и планируйте подход против него.',
      'Отдайте якорь на достаточном удалении — примерно 4–5 длин корпуса — и идите назад малым ходом.',
      'Подав кормовые концы, выберите якорную цепь, чтобы удерживать лодку от причала.',
    ],
    note: 'Не торопитесь: повторить неудачный подход всегда дешевле, чем продавливать его.',
  ),
  'wind': GuideText(
    title: 'Знайте местные ветры',
    summary: 'Название ветра говорит и о его характере.',
    points: <String>[
      'Летом мельтеми усиливается после полудня и стихает к вечеру — стройте день с учётом этого.',
      'Пойраз (северо-восток) сухой и жёсткий; лодос (юго-запад) влажный и обычно приносит волну.',
      'Выбирая бухту, исключайте открытые в сторону ветра; укрытие — со стороны берега.',
      'Раннее утро обычно самое спокойное время — переходы подлиннее планируйте на него.',
    ],
    note: 'Горные проходы и мысы могут локально удваивать ветер: прогноз описывает район, а не вашу бухту.',
  ),
  'forecast': GuideText(
    title: 'Как читать прогноз',
    summary: 'Смотрите на тенденцию, а не на одну цифру.',
    points: <String>[
      'Читайте скорость ветра вместе с порывами: порывы заметно превышают среднее значение.',
      'Смена направления важна не меньше силы: укрытая бухта за ночь может стать открытой.',
      'Сверяйте несколько источников; если они расходятся, неопределённость велика — оставьте план гибким.',
      'Дальше двух суток прогноз быстро теряет надёжность; обновляйте план каждое утро.',
    ],
    note: 'Официальные штормовые предупреждения всегда имеют приоритет.',
  ),
  'rules': GuideText(
    title: 'Расхождение судов',
    summary: 'Кто кого пропускает — несколько простых правил.',
    points: <String>[
      'Моторное судно уступает дорогу парусному; но в узком фарватере крупное судно не может маневрировать — уходите вы.',
      'При встрече двух парусных лодок преимущество у той, что несёт ветер с правого борта.',
      'Два моторных судна, идущие лоб в лоб, оба отворачивают вправо.',
      'Даже имея преимущество, вы обязаны избежать столкновения: правило не оправдывает аварию.',
    ],
    note: 'Показывайте намерение рано и явно: мелкие поправки курса другой лодке не видны.',
  ),
  'lights': GuideText(
    title: 'Ночной переход и огни',
    summary: 'Огонь, который вы видите в темноте, говорит о направлении судна.',
    points: <String>[
      'Правый борт зелёный, левый красный, кормовой огонь белый; видите оба цвета — судно идёт на вас.',
      'Стоящая на якоре лодка несёт один белый огонь — при ночном заходе в бухту ищите прежде всего их.',
      'Берегите ночное зрение: приглушите палубные огни и экраны, фонарь переведите в красный режим.',
      'Не заходите ночью в бухту, которую не видели днём: незнакомая вода в темноте вдвое теснее.',
    ],
  ),
  'vhf': GuideText(
    title: 'УКВ-радио и 16-й канал',
    summary: 'Радио — общий язык на море.',
    points: <String>[
      '16-й канал — для прослушивания и бедствия; разговор переводите на рабочий канал.',
      'Сначала слушайте, потом говорите. Схема вызова: имя вызываемой станции дважды, своё — один раз.',
      'Говорите коротко и ясно; закончив фразу, передавайте очередь словом «приём».',
      'Каналы марин и портов различаются: узнайте нужный до подхода.',
    ],
    note: 'В море держите радио включённым — первым вас может услышать сосед по стоянке.',
  ),
  'mayday': GuideText(
    title: 'Сигнал бедствия: MAYDAY',
    summary: 'Если есть угроза жизни — не медлите.',
    points: <String>[
      'Трижды «MAYDAY» на 16-м канале, затем название судна, координаты, характер опасности, число людей и какая помощь нужна.',
      'Координаты давайте в широте и долготе; по возможности добавьте пеленг от ближайшего заметного ориентира.',
      'Если на станции есть кнопка DSC, нажмите её первой: она автоматически передаёт номер и позицию.',
      'Если угрозы жизни нет, но помощь нужна, вызов подаётся словами «PAN PAN».',
    ],
    note: 'На побережье Турции экстренный номер береговой охраны — 158; '
        'страница «Экстренная помощь» в приложении набирает его одним касанием.',
  ),
  'mob': GuideText(
    title: 'Человек за бортом',
    summary: 'Первые тридцать секунд решают всё.',
    points: <String>[
      'Громко крикните: «Человек за бортом!» Один член экипажа только указывает на пострадавшего и не отводит глаз.',
      'Нажмите кнопку MOB или отметьте позицию; немедленно бросьте спасательный круг.',
      'Работая двигателем, помните о винте; подходите с наветра и под контролем.',
      'Заранее обсудите подъём: трап, конец, парусина. Поднять обессилевшего человека труднее, чем кажется.',
    ],
    note: 'Отрепетируйте манёвр с кранцем в спокойный день — пусть аварийный случай не будет первой попыткой.',
  ),
  'predeparture': GuideText(
    title: 'Проверка перед выходом',
    summary: 'Пять минут проверки — часы спокойствия.',
    points: <String>[
      'Двигатель: уровень масла и охлаждающей жидкости, ремень, открыт ли кингстон — идёт ли вода из выхлопа после пуска?',
      'Сухой ли трюм и работает ли помпа? Хватает ли топлива (правило третей: туда, обратно, резерв)?',
      'Палуба: концы уложены, кранцы на месте, шкоты свободны.',
      'Спасательные жилеты, аптечка и фонарь — на месте и доступны каждому?',
    ],
    note: 'Пункты перед выходом можно отмечать в чек-листе приложения.',
  ),
};
