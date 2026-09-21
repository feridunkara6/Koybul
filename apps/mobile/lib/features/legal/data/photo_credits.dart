/// FOTOĞRAF ATIF LİSTESİ — ÜRETİLMİŞ DOSYA (FAZ 0 K4, 2026-09; FAZ 3 TUR 1 güncellemesi).
///
/// Kaynak: apps/api/prisma/data/kapak_fotograflari.json — uygulamadaki her
/// kapak fotoğrafının atıf kaydı (fotoğrafçı/kaynak, lisans, kaynak sayfası).
/// ELLE DÜZENLENMEZ: yeni fotoğraf partisi eklendiğinde bu dosya aynı
/// betikle JSON'dan yeniden üretilir; elle liste tutulursa eninde sonunda
/// JSON'dan sapar ve atıf yükümlülüğü sessizce delinir.
///
/// Lisans alanı BOŞ olabilir: kaynak izniyle (ör. DERİA) kullanılan
/// fotoğraflarda var olmayan bir lisans adı UYDURULMAZ; atıf yalnız kaynağın
/// adını söyler (veri disiplini: kapak_fotograflari.json kuralları).
library;

/// Tek fotoğrafın atıf kaydı.
class PhotoCredit {
  const PhotoCredit({
    required this.place,
    required this.credit,
    required this.license,
    required this.sourceUrl,
  });

  /// Yer adı (konum kimliğinden türetilir; görsel amaçlı).
  final String place;

  /// Fotoğrafçı / kaynak atfı — hiçbir kayıtta boş olamaz (CC şartı).
  final String credit;

  /// Lisans kısa adı (ör. 'CC BY-SA 4.0'); kaynak-izni fotoğraflarında boş.
  final String license;

  /// Atfın bağlandığı kaynak sayfası.
  final String sourceUrl;
}

/// Tüm kapak fotoğraflarının atıfları (konum kimliğine göre sıralı).
const List<PhotoCredit> kPhotoCredits = <PhotoCredit>[
  PhotoCredit(
    place: 'Adakoy Marina Marmaris',
    credit: 'Bir_Ege_Hikayesi ©',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:48700_Adak%C3%B6y-Marmaris-Mu%C4%9Fla,_Turkey_-_panoramio_(1).jpg',
  ),
  PhotoCredit(
    place: 'Adamas Limani Milos',
    credit: 'Klearchos Kapoutsis from Santorini, Greece',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adamas_(4703820265).jpg',
  ),
  PhotoCredit(
    place: 'Aegina Limani',
    credit: 'Jorge Láscar from Australia',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Lascar_Island_of_Aegina_-_Main_harbour_(4518425007).jpg',
  ),
  PhotoCredit(
    place: 'Akarca Balikci Barinagi',
    credit: 'Yağmur Aydın',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Seferihisar_-_Akarca_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Alanya Marina',
    credit: 'Fotoğraf: Alanya Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.alanyamarina.com.tr',
  ),
  PhotoCredit(
    place: 'Alibey Cunda Adasi Limani',
    credit: 'collage bird\'s eye v…',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Cunda_Adas%C4%B1_(Alibey)_Ayval%C4%B1k_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Antalya Kaleici Yat Limani',
    credit: 'Ray Swi-hymn from Sijhih-Taipei, Taiwan',
    license: 'CC BY-SA 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:20180111_AntalyaMarina_5272_(25238627627).jpg',
  ),
  PhotoCredit(
    place: 'Asagiyapici Balikci Barinagi',
    credit: 'AycanD',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Asagiyap%C4%B1c%C4%B1_koyunun_gorunusu.jpg',
  ),
  PhotoCredit(
    place: 'Baba Island Koyu',
    credit: 'dronepicr',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Old_lighthouse_on_Baba_Adasi_island_with_a_view_of_Sarigerme,_Turkey_(49070263193).jpg',
  ),
  PhotoCredit(
    place: 'Bardakci Koyu',
    credit: 'Vano111ru',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bardak%C3%A7%C4%B1_Beach.jpg',
  ),
  PhotoCredit(
    place: 'Bayindir Limanagzi Kas Demirleme',
    credit: 'Tugceeakgunn91',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Antalya_-_Ka%C5%9F_-Limana%C4%9Fz%C4%B1.jpg',
  ),
  PhotoCredit(
    place: 'Bedri Rahmi Samandira Sahasi',
    credit: 'Raicem',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Fish_Figure_on_a_Rock_Painted_By_Bedri_Rahmi_Ey%C3%BCbo%C4%9Flu,_located_in_Bedri_Rahmi_Bay_in_G%C3%B6cek.jpg',
  ),
  PhotoCredit(
    place: 'Binlik Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Bitez Koyu Demirleme',
    credit: 'Tanya Dedyukhina',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bodrum_Bitez_bay_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Bogsak Koyu',
    credit: 'Yasirarslan',
    license: 'Public domain',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bo%C4%9Fsak_Island.jpg',
  ),
  PhotoCredit(
    place: 'Boynuzbuku Samandira Sahasi',
    credit: 'Jorge Franganillo',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Boynuzb%C3%BCk%C3%BC_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Bozburun Yat Yanasma Yeri',
    credit: 'Bir_Ege_Hikayesi ©',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Merkez,_48710_Bozburun-Marmaris-Mu%C4%9Fla,_Turkey_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Bozcaada Limani',
    credit: 'Filanca',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bozcaada_liman.jpg',
  ),
  PhotoCredit(
    place: 'Bozukkale Loryma Demirleme',
    credit: 'Marmaracalypso',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Loryma_(3).jpg',
  ),
  PhotoCredit(
    place: 'Buyukova Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Cinarcik Balikci Barinagi',
    credit: 'M. PINARCI',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:%C3%87%C4%B1narc%C4%B1k_-_panoramio_(39).jpg',
  ),
  PhotoCredit(
    place: 'D Marin Gocek',
    credit: 'Poet Laureate',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Port_G%C3%B6cek_early_evening.jpg',
  ),
  PhotoCredit(
    place: 'D Marin Turgutreis',
    credit: 'Tanya Dedyukhina',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Turgutreis_-_panoramio_(11).jpg',
  ),
  PhotoCredit(
    place: 'Dana Adasi',
    credit: 'Yılmaz Kilim',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Dana_Adas%C4%B1_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Datca Yat Limani',
    credit: 'Abdullah kıyga',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Dat%C3%A7a,_yachts_harbour_*%C2%A9Abdullah_Kiyga_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Davutlar Balikci Barinagi',
    credit: 'Omur Tanyel',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Sunset_davutlar_coast.jpg',
  ),
  PhotoCredit(
    place: 'Degirmen Buku Ingiliz Limani',
    credit: 'Nevit Dilmen (talk)',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ingiliz_limani_04404_-_04406.jpg',
  ),
  PhotoCredit(
    place: 'Denizkoy Koyu',
    credit: 'Kadı',
    license: 'CC BY 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Denizk%C3%B6y,_Dikili.jpg',
  ),
  PhotoCredit(
    place: 'Domuz Island Koyu',
    credit: 'Jorge Franganillo',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Domuz_Adas%C4%B1_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Eceabat Balikci Barinagi',
    credit: 'Dosseman',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Eceabat_in_2003_1404.jpg',
  ),
  PhotoCredit(
    place: 'Enez Balikci Barinagi',
    credit: 'Sinan Şahin',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Enez_Liman%C4%B1..._-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Ermoupoli Limani Syros',
    credit: 'Hans Peter Schaefer, http://www.reserv-a-rt.de',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Syros_Ano_Syros_u_Ermoupolis140707.jpg',
  ),
  PhotoCredit(
    place: 'Esenkoy Balikci Barinagi',
    credit: 'Eneshamdi2007',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Esenk%C3%B6y,%C3%87%C4%B1narc%C4%B1k,Yalova.jpg',
  ),
  PhotoCredit(
    place: 'Fethiye Limani',
    credit: 'Dosseman',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Fethiye_Harbour_area_in_2011_5727.jpg',
  ),
  PhotoCredit(
    place: 'Fiskardo Limani',
    credit: 'Dan Taylor from London, UK',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Fiscardo,_Kefalonia_10-2003_02.jpg',
  ),
  PhotoCredit(
    place: 'G Marina Kemer',
    credit: 'Abdullah kıyga',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:KEMER_MAR%C4%B0NA_%C2%A9Abdullah_Kiyga_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Gaios Limani Paksos',
    credit: 'Bogdan Giuşcă',
    license: 'CC BY-SA 2.5',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Paxos_gaios_port_bgiu.jpg',
  ),
  PhotoCredit(
    place: 'Garipce Village Balikci Barinagi',
    credit: 'Maurice Flesier',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Garip%C3%A7e,_Sar%C4%B1yer.jpg',
  ),
  PhotoCredit(
    place: 'Gemiler Adasi Demirleme',
    credit: 'Cobija',
    license: 'CC0 1.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Gemiler_Adas%C4%B1_ve_koy_panoramik.jpg',
  ),
  PhotoCredit(
    place: 'Gemlik Balikci Barinagi',
    credit: 'Mustafa DUMAN',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Gemlik_liman%C4%B1_gemlik_bursa_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Gobun Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Gocek Adasi Bati Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Gocek Belediye Iskelesi',
    credit: 'Herbert wie',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:G%C3%B6cek_Hafen_T%C3%BCrkei.jpg',
  ),
  PhotoCredit(
    place: 'Gocek Dogu Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Gocek Village Port Marina',
    credit: 'Fotoğraf: Göcek Village Port Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/gocek-village-port',
  ),
  PhotoCredit(
    place: 'Gokceada Kuzu Limani',
    credit: 'Bilderbrei',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:G%C3%B6kceada_Kuzu_Limani_1.jpg',
  ),
  PhotoCredit(
    place: 'Golturkbuku Balikci Barinagi',
    credit: 'bynyalcin',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:G%C3%B6lt%C3%BCrkb%C3%BCk%C3%BC-Bodrum-Mu%C4%9Fla,_Turkey_-_panoramio_(2).jpg',
  ),
  PhotoCredit(
    place: 'Gumusluk Iskeleleri',
    credit: 'Koray',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:G%C3%BCm%C3%BC%C5%9Fl%C3%BCk,_Bodrum.jpg',
  ),
  PhotoCredit(
    place: 'Gumusluk Koyu Demirleme',
    credit: 'Bright estrellas',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bodrum_G%C3%BCm%C3%BC%C5%9Fl%C3%BCk.jpg',
  ),
  PhotoCredit(
    place: 'Gundogan Balikci Barinagi',
    credit: 'Şadi Bora Karamanoğlu',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Gundogan.jpg',
  ),
  PhotoCredit(
    place: 'Guneyli Balikci Barinagi',
    credit: 'Hamdigumus',
    license: 'CC0 1.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Saros_G%C3%BCneylide_G%C3%BCnbat%C4%B1m%C4%B1_2.jpg',
  ),
  PhotoCredit(
    place: 'Gunluk Atbuku Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Gunluklu Koyu Demirleme',
    credit: 'Jorge Franganillo',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:G%C3%BCnl%C3%BCkl%C3%BC_Koyu_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Guzelbahce Fishing Harbour And Balikci Barinagi',
    credit: 'BSRF',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:G%C3%BCzelbah%C3%A7e_%C4%B0skelesi_(2).jpg',
  ),
  PhotoCredit(
    place: 'Halki Emporios Rihtimi',
    credit: 'Oliver H',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Emporio_port_in_Halki_island.jpg',
  ),
  PhotoCredit(
    place: 'Hydra Limani',
    credit: 'dronepicr',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Harbour_of_Hydra_island_(43058393960).jpg',
  ),
  PhotoCredit(
    place: 'Ic Cesme Marina',
    credit: 'Irfan Parlar',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Cesme_Marina.jpg',
  ),
  PhotoCredit(
    place: 'Inceburun Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Izmir Marina',
    credit: 'BSRF',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:%C4%B0zmir_Marina,_May_2023_02.jpg',
  ),
  PhotoCredit(
    place: 'Kale Pansiyon Iskelesi',
    credit: 'Josep M. Gracia',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:KAL_-_Panoramic_view_of_Kalekoy_and_Simena_Castle,_Turkey,_2021.jpg',
  ),
  PhotoCredit(
    place: 'Kalekoy Simena Restoran Pontonlari',
    credit: 'Seynaeve',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Simena_0230.jpg',
  ),
  PhotoCredit(
    place: 'Kalymnos Pothia Limani',
    credit: 'Κ. Καλογερόπουλος Kalogeropoulos',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Calymnos_harbour.jpg',
  ),
  PhotoCredit(
    place: 'Kandiye Limani Girit',
    credit: 'Stu\'s Images',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Venetian_Fortress,_Heraklion,_Crete.JPG',
  ),
  PhotoCredit(
    place: 'Kara Ada Demirleme',
    credit: 'Alessandro57',
    license: 'Public domain',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:KaraAda20060920.jpg',
  ),
  PhotoCredit(
    place: 'Karatas Fisher Limani',
    credit: 'Zeynel Cebeci',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Port_of_Karata%C5%9F_03.jpg',
  ),
  PhotoCredit(
    place: 'Kas Belediye Limani',
    credit: 'HALUK COMERTEL',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kaya_mezar_ve_liman-Ka%C5%9F_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Katapola Limani Amorgos',
    credit: 'Zde',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Katapola_bay,_Amorgos,_213202.jpg',
  ),
  PhotoCredit(
    place: 'Katranci Koyu',
    credit: 'Merih Sezgin',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Katranc%C4%B1,_Fethiye_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Kaynarpinar Balikci Barinagi',
    credit: 'Atacameño',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kaynarp%C4%B1nar.jpg',
  ),
  PhotoCredit(
    place: 'Keci Buku Demirleme',
    credit: 'Arif Sipahi',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:K%C4%B1zkumu_Orhaniye_Marmaris.jpg',
  ),
  PhotoCredit(
    place: 'Kelebekler Vadisi Demirleme',
    credit: 'Htkava',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kelebekler_Vadisi_-_Butterfly_Valley,_Turkey.jpg',
  ),
  PhotoCredit(
    place: 'Kilitbahir Balikci Barinagi',
    credit: 'Kadı',
    license: 'CC BY 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kilitbahir,_%C3%87anakkale_(26102024).jpg',
  ),
  PhotoCredit(
    place: 'Kille Buku',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Kizilada Fener Restorani',
    credit: 'Николай Максимович',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:The_Gulf_of_Fethiye._Kizilada_Restaurant_and_K%C4%B1z%C4%B1lada_Feneri.jpg',
  ),
  PhotoCredit(
    place: 'Kizkalesi Koyu',
    credit: 'YG01',
    license: 'CC BY 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kizkalesi,_Erdemli.IMG_3490.jpg',
  ),
  PhotoCredit(
    place: 'Kos Eski Liman Mandraki',
    credit: 'Asurnipal',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kos-Harbour-01ASD.jpg',
  ),
  PhotoCredit(
    place: 'Kumyaka Balikci Barinagi',
    credit: 'Erdoğan Orçin',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kumyaka_-_Si%C4%9Fi_-_Sygi.jpg',
  ),
  PhotoCredit(
    place: 'Kursunlu Marina',
    credit: 'A. Kerim ŞENGEL',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Kur%C5%9Funlu_Bal%C4%B1k%C3%A7%C4%B1_Bar%C4%B1na%C4%9F%C4%B1_-03_May%C4%B1s_2013_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Lakka Koyu Paksos',
    credit: 'Jess Stubenbord',
    license: 'CC0 1.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Lakka_bay_20210606.jpg',
  ),
  PhotoCredit(
    place: 'Letoonia Marinet Fethiye',
    credit: 'Николай Максимович',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Letoonia_club,_Fethiye_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Lindos Koyu',
    credit: 'Ввласенко',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Pier_at_Lindos._Rhodes,_Greece.jpg',
  ),
  PhotoCredit(
    place: 'Loryma Restaurant Bozukkale',
    credit: 'Marmaracalypso',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Loryma_(3).jpg',
  ),
  PhotoCredit(
    place: 'Marinturk Gocek Exclusive',
    credit: 'Fotoğraf: Göcek Exclusive Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/marinalar/gocek-exclusive',
  ),
  PhotoCredit(
    place: 'Marti Marina Orhaniye',
    credit: 'Fotoğraf: Martı Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.marti.com.tr/marti-marina',
  ),
  PhotoCredit(
    place: 'Marti Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Merdivenli Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Milta Bodrum Marina',
    credit: 'Michal Osmenda from Brussels, Belgium',
    license: 'CC BY-SA 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Bodrum_marina,_Turkey_(5653802003).jpg',
  ),
  PhotoCredit(
    place: 'My Marina Ekincik',
    credit: 'Николай Максимович',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ekincik_My_Marina_-_panoramio_(3).jpg',
  ),
  PhotoCredit(
    place: 'Naoussa Limani Paros',
    credit: 'ian freeman',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Naoussa_Harbour_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Narli Koyu Balikci Barinagi',
    credit: 'A. Kerim ŞENGEL',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Narl%C4%B1_Bal%C4%B1k%C3%A7%C4%B1_Bar%C4%B1na%C4%9F%C4%B1_-03_May%C4%B1s_2013_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Netsel Marmaris Marina',
    credit: 'George Chernilevsky',
    license: 'Public domain',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Marmaris_marina_2019_G2.jpg',
  ),
  PhotoCredit(
    place: 'Nisyros Mandraki Limani',
    credit: 'Karelj',
    license: 'Public domain',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Nisyros_port_Mandraki_1.jpg',
  ),
  PhotoCredit(
    place: 'Olimpos Koyu',
    credit: 'Oystercard',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:View_of_Olimpos_Plaj%C4%B1_with_Tahtal%C4%B1_Mountain_in_the_Background.jpg',
  ),
  PhotoCredit(
    place: 'Orak Island Koyu',
    credit: 'Tamer BÜKE',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Orak_Adas%C4%B1_2_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Osmanaga Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Palamutbuku Balikci Barinagi',
    credit: 'Semih Ekinci',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Palamutbuku_Island_-_Palamutb%C3%BCk%C3%BC_Adas%C4%B1_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Patara Koyu',
    credit: 'Esginmurat',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Patara_Plaj%C4%B1.jpg',
  ),
  PhotoCredit(
    place: 'Patmos Skala Rihtimi',
    credit: 'Chris Vlachos',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Skala-of-patmos.JPG',
  ),
  PhotoCredit(
    place: 'Phaselis Koylari Demirleme',
    credit: 'Mike like0708',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Phaselis_beach.jpg',
  ),
  PhotoCredit(
    place: 'Port Alacati Marina',
    credit: 'David Broad',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Cesme_-_Alacati_Marina_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Pythagorio Limani Samos',
    credit: 'Orthodox33',
    license: 'Public domain',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Pythagorio.jpg',
  ),
  PhotoCredit(
    place: 'Rodos Mandraki Limani',
    credit: 'Pjotr Mahhonin',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Mandraki_Harbour_Entrance_Port_of_Rhodes_21_August_2023.jpg',
  ),
  PhotoCredit(
    place: 'Rumeli Feneri Balikci Barinagi',
    credit: 'VikiPicture',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Rumeli_Feneri,_Sar%C4%B1yer_p1.JPG',
  ),
  PhotoCredit(
    place: 'Sapli Island Koyu',
    credit: 'faktor1komma5 /by Claus P. Heibel from Didim/Aydın, Türkiye',
    license: 'CC BY 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Sunset_at_Sapl%C4%B1_Adas%C4%B1_-_Flickr_-_faktor1komma5.jpg',
  ),
  PhotoCredit(
    place: 'Sarsala Samandira Sahasi',
    credit: 'Raicem',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Sarsala_Bay_in_Dalaman_from_above.jpg',
  ),
  PhotoCredit(
    place: 'Sedir Adasi Demirleme',
    credit: 'Semih Ekinci',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Cleopatra_Beach_-_Sedir_Island_-_Kleopatra_Plaj%C4%B1_-_Sedir_Adas%C4%B1_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Setur Antalya Marina',
    credit: 'Fotoğraf: Setur Antalya Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/antalya',
  ),
  PhotoCredit(
    place: 'Setur Ayvalik Marina',
    credit: 'Fotoğraf: Setur Ayvalık Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/ayvalik',
  ),
  PhotoCredit(
    place: 'Setur Cesme Marina',
    credit: 'Fotoğraf: Setur Çeşme Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/cesme',
  ),
  PhotoCredit(
    place: 'Setur Finike Marina',
    credit: 'Fotoğraf: Setur Finike Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/finike',
  ),
  PhotoCredit(
    place: 'Setur Kalamis Fenerbahce Marina',
    credit: 'Kadı',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Fenerbah%C3%A7e_Yat_Liman%C4%B1.jpg',
  ),
  PhotoCredit(
    place: 'Setur Kas Marina',
    credit: 'Fotoğraf: Setur Kaş Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/makmarin-kas',
  ),
  PhotoCredit(
    place: 'Setur Kusadasi Marina',
    credit: 'Zeynel Cebeci',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ku%C5%9Fadas%C4%B1_Marina_03.jpg',
  ),
  PhotoCredit(
    place: 'Setur Yalova Marina',
    credit: 'Fotoğraf: Setur Yalova Marina (resmî site)',
    license: '',
    sourceUrl: 'https://www.seturmarinas.com/en/marinas/yalova',
  ),
  PhotoCredit(
    place: 'Sig Liman Selimiye',
    credit: 'Elelicht',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Selimiye_3.JPG',
  ),
  PhotoCredit(
    place: 'Sigacik Balikci Barinagi',
    credit: 'BSRF',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:S%C4%B1%C4%9Fac%C4%B1k_02.jpg',
  ),
  PhotoCredit(
    place: 'Siralibuk Koyu',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Sultanice Balikci Barinagi',
    credit: 'Yavuzsultamselim22',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Sultani%C3%A7e_Sahil.jpg',
  ),
  PhotoCredit(
    place: 'Suluada Koyu',
    credit: 'Erturkercin',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Adrasan_Suluada_Drone.jpg',
  ),
  PhotoCredit(
    place: 'Symi Gialos Rihtimi',
    credit: 'SymiArt',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Symi_harbour.jpg',
  ),
  PhotoCredit(
    place: 'Symi Panormitis Iskelesi',
    credit: 'A.F.E.Bean',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Panorama_Blick_auf_Schiffanleger_Panormitis.jpg',
  ),
  PhotoCredit(
    place: 'Teos Marina',
    credit: 'BSRF',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:S%C4%B1%C4%9Fac%C4%B1k_Castle,_Harbour_and_Teos_Marina_01.jpg',
  ),
  PhotoCredit(
    place: 'Tersane Adasi Koyu',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
  PhotoCredit(
    place: 'Tilos Livadia Rihtimi',
    credit: 'freddie boy',
    license: 'CC BY-SA 2.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Livadhia_Tilos_2.jpg',
  ),
  PhotoCredit(
    place: 'Torba Balikci Barinagi',
    credit: 'Dw updike',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Torba_Bay.JPG',
  ),
  PhotoCredit(
    place: 'Toslaklar Koyu',
    credit: 'Yılmaz Kilim',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Toslaklar_Koyu_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Ucagiz Rihtimi',
    credit: 'Dosseman',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:%C3%9C%C3%A7a%C4%9F%C4%B1z_0043.jpg',
  ),
  PhotoCredit(
    place: 'Vlychada Marina Santorini',
    credit: 'Dietmar Rabich',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Santorin_(GR),_Exomytis,_Marina_Exomitis-Vlychada_--_2017_--_2819.jpg',
  ),
  PhotoCredit(
    place: 'Yalikavak Marina',
    credit: 'CeeGee',
    license: 'CC0 1.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Yal%C4%B1kavakMarina_(2).jpg',
  ),
  PhotoCredit(
    place: 'Yalova Balikci Barinagi',
    credit: 'Annikat53',
    license: 'CC BY-SA 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Yalova_Seaside.JPG',
  ),
  PhotoCredit(
    place: 'Yaprakli Koy Koyu',
    credit: 'Wayway21',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Yaprakl%C4%B1_Koy.jpg',
  ),
  PhotoCredit(
    place: 'Yassica Adalari',
    credit: 'Jorge Franganillo',
    license: 'CC BY 3.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Yass%C4%B1ca_Adalar%C4%B1_-_panoramio.jpg',
  ),
  PhotoCredit(
    place: 'Yesilovacik Fisher Limani',
    credit: 'Nedim Ardoğa',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ye%C5%9Filovac%C4%B1k_harbor.jpg',
  ),
  PhotoCredit(
    place: 'Zea Marina',
    credit: 'Palickap',
    license: 'CC BY-SA 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Piraeus,_marina_Zea_03.JPG',
  ),
  PhotoCredit(
    place: 'Zeytin Adasi Samandira Sahasi',
    credit: 'Fotoğraf: DERİA (Türkiye Çevre Ajansı)',
    license: '',
    sourceUrl: 'https://deria.gov.tr',
  ),
];
