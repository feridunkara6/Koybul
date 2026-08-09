/// BAKIM KATALOĞU (v2.0 "Teknem", kurucu onayı 2026-08): 10 tipik kalem,
/// dört dilde. Aralıklar YAYGIN UYGULAMAYA dayalı ÖNERİlerdir — üretici
/// kılavuzu ve kullanım yoğunluğu her zaman önceliklidir; kaptan her kalemin
/// aralığını kendi teknesine göre değiştirebilir.
///
/// YAPI (Akademi ile aynı): kimlik + ikon + aralık TEK yerde; metinler dil
/// sözlüklerinde. Böylece her dilde AYNI 10 kalem garanti olur.
library;

import 'package:dockly_ui/dockly_ui.dart';

import '../../../core/l10n/app_locale.dart';
import '../domain/maintenance.dart';

class _Item {
  const _Item(this.id, this.icon, this.days);
  final String id;
  final DocklyIconData icon;
  final int days;
}

/// Kalemler ve önerilen aralıkları (gün).
const List<_Item> _items = <_Item>[
  _Item('engine_oil', DocklyIcons.amTool, 365), // sezonluk
  _Item('impeller', DocklyIcons.amTool, 365),
  _Item('anodes', DocklyIcons.amElectricity, 180),
  _Item('antifouling', DocklyIcons.amCrane, 365),
  _Item('battery', DocklyIcons.amElectricity, 180),
  _Item('bilge_pump', DocklyIcons.amPumpOut, 90),
  _Item('lifejackets', DocklyIcons.checkCircle, 365),
  _Item('flares', DocklyIcons.errorOutline, 365),
  _Item('rigging', DocklyIcons.sailing, 365),
  _Item('lines_fenders', DocklyIcons.amMooring, 180),
];

/// Katalogdaki kalem sayısı (arayüz ve testler bu sabiti okur).
const int kMaintenanceTaskCount = 10;

class _Text {
  const _Text(this.title, this.hint);
  final String title;
  final String hint;
}

/// Seçili dildeki bakım kalemleri. Metin eksikse İngilizcesine düşer
/// (dürüst yedek: kaptan boş satır görmez).
List<MaintenanceTask> maintenanceCatalog(AppLocale locale) {
  final Map<String, _Text> table = _tableOf(locale);
  final List<MaintenanceTask> out = <MaintenanceTask>[];
  for (final _Item i in _items) {
    final _Text? t = table[i.id] ?? _en[i.id];
    if (t == null) continue;
    out.add(MaintenanceTask(
      id: i.id,
      icon: i.icon,
      intervalDays: i.days,
      title: t.title,
      hint: t.hint,
    ));
  }
  return out;
}

Map<String, _Text> _tableOf(AppLocale locale) {
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

const Map<String, _Text> _tr = <String, _Text>{
  'engine_oil': _Text('Motor yağı ve filtresi',
      'Sezon başında ya da üreticinin verdiği çalışma saatinde değiştirilir.'),
  'impeller': _Text('Deniz suyu pompası empelleri',
      'Kauçuk kanatlar yorulur; yedeğini teknede bulundur.'),
  'anodes': _Text('Anotlar (çinko)',
      'Yarıdan fazlası eridiyse beklemeden yenile — şaft ve pervaneyi korur.'),
  'antifouling': _Text('Karina boyası ve tekne dibi',
      'Kirlenen karina hızı düşürür, yakıtı artırır; genelde yılda bir.'),
  'battery': _Text('Akü ve şarj sistemi',
      'Kutup başlarını temizle, gerilimi ölç; kışın şarjda tut.'),
  'bilge_pump': _Text('Sintine pompası ve alarmı',
      'Elle çalıştırıp suyu bastığını gör; şamandırayı kaldırarak dene.'),
  'lifejackets': _Text('Can yelekleri ve kişisel donanım',
      'Otomatik yeleklerin tüpünü ve tabletini kontrol et; kayışları dene.'),
  'flares': _Text('İşaret fişekleri ve yangın söndürücü',
      'Son kullanma tarihlerine bak; süresi geçmişi kurallara uygun teslim et.'),
  'rigging': _Text('Arma, yelken ve donanım',
      'Tel uçlarını, çarmık dilcik pimlerini ve yelken dikişlerini gözden geçir.'),
  'lines_fenders': _Text('Halatlar ve usturmaçalar',
      'Aşınan gözleri ve yıpranmış halatları değiştir; usturmaça iplerini kontrol et.'),
};

const Map<String, _Text> _en = <String, _Text>{
  'engine_oil': _Text('Engine oil and filter',
      'Change at the start of the season or at the maker\'s running hours.'),
  'impeller': _Text('Raw-water pump impeller',
      'The rubber vanes fatigue with use; keep a spare aboard.'),
  'anodes': _Text('Anodes (zincs)',
      'Renew once more than half has gone — they protect shaft and propeller.'),
  'antifouling': _Text('Antifouling and hull bottom',
      'A fouled hull costs speed and fuel; usually once a year.'),
  'battery': _Text('Batteries and charging',
      'Clean the terminals, check the voltage, keep them charged over winter.'),
  'bilge_pump': _Text('Bilge pump and alarm',
      'Run it by hand and watch it pump; lift the float switch to test it.'),
  'lifejackets': _Text('Lifejackets and personal gear',
      'Check cylinders and bobbins on automatic jackets; try the harnesses.'),
  'flares': _Text('Flares and fire extinguisher',
      'Check expiry dates; dispose of out-of-date items the proper way.'),
  'rigging': _Text('Rig, sails and deck gear',
      'Look over wire ends, shroud clevis pins and sail stitching.'),
  'lines_fenders': _Text('Lines and fenders',
      'Replace chafed eyes and tired lines; check the fender lanyards.'),
};

const Map<String, _Text> _es = <String, _Text>{
  'engine_oil': _Text('Aceite y filtro del motor',
      'Cámbialo al inicio de temporada o a las horas que indique el fabricante.'),
  'impeller': _Text('Turbina de la bomba de agua salada',
      'Las palas de goma se fatigan; lleva un repuesto a bordo.'),
  'anodes': _Text('Ánodos (zincs)',
      'Renuévalos cuando se haya consumido más de la mitad: protegen eje y hélice.'),
  'antifouling': _Text('Patente y fondo del casco',
      'Un casco sucio resta velocidad y gasta combustible; normalmente una vez al año.'),
  'battery': _Text('Baterías y carga',
      'Limpia los bornes, mide la tensión y mantenlas cargadas en invierno.'),
  'bilge_pump': _Text('Bomba de achique y alarma',
      'Acciónala a mano y comprueba que achica; prueba el interruptor de boya.'),
  'lifejackets': _Text('Chalecos y equipo personal',
      'Revisa botella y pastilla de los chalecos automáticos; prueba los arneses.'),
  'flares': _Text('Bengalas y extintor',
      'Mira las fechas de caducidad; entrega lo caducado según la normativa.'),
  'rigging': _Text('Jarcia, velas y herrajes',
      'Revisa terminales, pasadores de obenques y costuras de las velas.'),
  'lines_fenders': _Text('Cabos y defensas',
      'Cambia gazas rozadas y cabos cansados; revisa las driza de las defensas.'),
};

const Map<String, _Text> _ru = <String, _Text>{
  'engine_oil': _Text('Масло и фильтр двигателя',
      'Меняйте в начале сезона или по моточасам, указанным производителем.'),
  'impeller': _Text('Крыльчатка забортной помпы',
      'Резиновые лопасти изнашиваются; держите запасную на борту.'),
  'anodes': _Text('Аноды (цинки)',
      'Меняйте, когда стёрлось больше половины, — они защищают вал и винт.'),
  'antifouling': _Text('Необрастающая краска и днище',
      'Обросшее днище крадёт скорость и топливо; обычно раз в год.'),
  'battery': _Text('Аккумуляторы и зарядка',
      'Очистите клеммы, измерьте напряжение, зимой держите на подзарядке.'),
  'bilge_pump': _Text('Трюмная помпа и сигнализация',
      'Включите вручную и убедитесь, что откачивает; проверьте поплавок.'),
  'lifejackets': _Text('Спасжилеты и снаряжение',
      'Проверьте баллон и таблетку автоматических жилетов, примерьте страховку.'),
  'flares': _Text('Пиротехника и огнетушитель',
      'Проверьте сроки годности; просроченное сдайте по правилам.'),
  'rigging': _Text('Такелаж, паруса и палубное оборудование',
      'Осмотрите концы тросов, шплинты вант и швы парусов.'),
  'lines_fenders': _Text('Концы и кранцы',
      'Замените перетёртые огоны и уставшие концы; проверьте шнуры кранцев.'),
};
