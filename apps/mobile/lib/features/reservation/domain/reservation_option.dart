import 'package:dockly_api/dockly_api.dart' show Contact;

/// Rezervasyonu BAŞLATAN kanallar (v1.0 ürün stratejisi). Öncelik sırası:
/// telefon → WhatsApp → e-posta → web/online-rezervasyon. Otomatik rezervasyon
/// YAPMAZ; mevcut iletişim yöntemiyle süreci başlatır. v2'de aynı UX korunarak
/// online rezervasyona geçilecek.
enum ReservationChannel { phone, whatsapp, email, website }

/// Açılabilir tek bir rezervasyon-başlatma seçeneği.
class ReservationOption {
  const ReservationOption({
    required this.channel,
    required this.uri,
    required this.label,
  });

  final ReservationChannel channel;
  final Uri uri;
  final String label;
}

/// Rezervasyon talebi için hazır mesaj (WhatsApp/e-posta). Tekne boyu yerel
/// profilden gelirse mesaja eklenir; yoksa nazikçe "teknem" denir.
String buildReservationMessage({double? boatLengthM}) {
  final String boatPart =
      boatLengthM != null ? '${_fmtLen(boatLengthM)} metre teknem' : 'teknem';
  return 'Merhaba. Koybul uygulaması üzerinden marinanızı buldum. '
      '$boatPart için uygunluk hakkında bilgi almak ve rezervasyon talebi '
      'oluşturmak istiyorum.';
}

/// Lokasyonun iletişim yöntemlerini strateji öncelik sırasıyla açılabilir
/// seçeneklere çevirir. Açılamayan/boş değerler ve rezervasyon-başlatmaya uygun
/// olmayan tipler (VHF, Instagram vb.) atlanır. Saf fonksiyon → test edilebilir.
List<ReservationOption> resolveReservationOptions(
  List<Contact> contacts, {
  double? boatLengthM,
}) {
  final String message = buildReservationMessage(boatLengthM: boatLengthM);
  final List<ReservationOption> out = <ReservationOption>[];

  final String? phone = _firstValue(contacts, 'phone');
  if (phone != null) {
    final Uri? u = _phoneUri(phone);
    if (u != null) {
      out.add(ReservationOption(channel: ReservationChannel.phone, uri: u, label: 'Ara'));
    }
  }

  final String? wa = _firstValue(contacts, 'whatsapp');
  if (wa != null) {
    final Uri? u = _whatsappUri(wa, message);
    if (u != null) {
      out.add(ReservationOption(
          channel: ReservationChannel.whatsapp, uri: u, label: 'WhatsApp\'tan yaz'));
    }
  }

  final String? email = _firstValue(contacts, 'email');
  if (email != null) {
    final Uri? u = _emailUri(email, message);
    if (u != null) {
      out.add(ReservationOption(
          channel: ReservationChannel.email, uri: u, label: 'E-posta gönder'));
    }
  }

  // Online rezervasyon linki — genel web sitesinden ÖNCE gelir (strateji öncelik 4).
  final String? resv = _firstValue(contacts, 'reservation_link');
  if (resv != null) {
    final Uri? u = _websiteUri(resv);
    if (u != null) {
      out.add(ReservationOption(
          channel: ReservationChannel.website, uri: u, label: 'Online rezervasyon'));
    }
  }

  final String? web = _firstValue(contacts, 'website');
  if (web != null) {
    final Uri? u = _websiteUri(web);
    if (u != null) {
      out.add(ReservationOption(
          channel: ReservationChannel.website, uri: u, label: 'Web sitesinden'));
    }
  }

  return out;
}

/// Belirtilen tipteki ilk açılabilir değeri döndürür; birincil (isPrimary) varsa
/// onu tercih eder.
String? _firstValue(List<Contact> contacts, String type) {
  Contact? primary;
  Contact? any;
  for (final Contact c in contacts) {
    if (c.type != type || c.value.trim().isEmpty) continue;
    any ??= c;
    if (c.isPrimary) {
      primary = c;
      break;
    }
  }
  return (primary ?? any)?.value.trim();
}

Uri? _phoneUri(String v) {
  final String d = _telDigits(v);
  return d.isEmpty ? null : Uri.parse('tel:$d');
}

Uri? _whatsappUri(String v, String message) {
  final String d = _waDigits(v);
  if (d.isEmpty) return null;
  return Uri.parse('https://wa.me/$d?text=${Uri.encodeComponent(message)}');
}

Uri? _emailUri(String v, String message) {
  final String addr = v.trim();
  if (addr.isEmpty) return null;
  final String query = 'subject=${Uri.encodeComponent('Rezervasyon Talebi')}'
      '&body=${Uri.encodeComponent(message)}';
  return Uri.parse('mailto:$addr?$query');
}

Uri? _websiteUri(String v) {
  final String s =
      (v.startsWith('http://') || v.startsWith('https://')) ? v : 'https://$v';
  return Uri.tryParse(s);
}

String _telDigits(String v) {
  final bool plus = v.trimLeft().startsWith('+');
  final String d = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return '';
  return plus ? '+$d' : d;
}

String _waDigits(String v) {
  String d = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('0')) d = '90${d.substring(1)}';
  return d;
}

String _fmtLen(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
