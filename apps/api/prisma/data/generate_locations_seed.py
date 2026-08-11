#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Veri edinimi partilerinden (data/*.json) seed_locations.sql üretir.

Kurallar (Faz 5 veri edinimi):
- Enum/kod doğrulaması: amenity/service/contact tipleri şemadaki whitelist'e uymalı.
- Koordinat akıl kontrolü: Türkiye sınırlayıcı kutusu içinde olmalı.
- Slug benzersizliği + isim benzerliğiyle mükerrer kontrolü.
- Üretilen SQL tamamen idempotent (ON CONFLICT DO NOTHING) — CI seed'i iki kez koşar.
Kullanım: python3 generate_locations_seed.py  (bu klasörden)
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

AMENITIES = {"electricity", "water", "fuel", "restaurant", "shower", "market", "laundry",
             "wifi", "security", "wc", "pump_out", "crane", "travel_lift", "technical_service"}
SERVICES = {"mooring_assist", "technical_service", "crane", "winter_storage", "boat_wash", "diver"}
CONTACT_TYPES = {"phone", "whatsapp", "email", "website", "vhf", "instagram", "facebook"}
HOLDING_TYPES = {"sand", "mud", "weed", "rock", "mixed"}  # ck_anchorage_details_holding_type
TYPE_IDS = {"private_marina": 1, "municipal_marina": 2, "municipal_pier": 3, "guest_mooring": 4,
            "restaurant_pier": 5, "fuel_pier": 6, "boat_club": 7, "mooring_point": 8, "buoy": 9}
# Ülke başına kaba sınır kutusu (deniz alanları dahil). Kayıtlar varsayılan TR;
# "countryCode" alanıyla diğer ülkeler eklenir (v1 genişleme: GR).
COUNTRY_BOUNDS = {
    "TR": ((35.5, 42.5), (25.0, 45.0)),
    "GR": ((34.5, 42.0), (19.0, 30.0)),
}

PROVINCES = {
    "istanbul": "İstanbul", "yalova": "Yalova", "balikesir": "Balıkesir", "izmir": "İzmir",
    "aydin": "Aydın", "mugla": "Muğla", "antalya": "Antalya", "mersin": "Mersin",
    "canakkale": "Çanakkale", "bursa": "Bursa", "tekirdag": "Tekirdağ",
    "kocaeli": "Kocaeli",
}
DISTRICTS = {
    "istanbul-kadikoy": ("istanbul", "Kadıköy"), "istanbul-bakirkoy": ("istanbul", "Bakırköy"),
    "istanbul-tuzla": ("istanbul", "Tuzla"), "istanbul-beylikduzu": ("istanbul", "Beylikdüzü"),
    "istanbul-pendik": ("istanbul", "Pendik"), "yalova-merkez": ("yalova", "Merkez"),
    "balikesir-ayvalik": ("balikesir", "Ayvalık"), "izmir-cesme": ("izmir", "Çeşme"),
    "izmir-seferihisar": ("izmir", "Seferihisar"), "aydin-kusadasi": ("aydin", "Kuşadası"),
    "aydin-didim": ("aydin", "Didim"), "mugla-marmaris": ("mugla", "Marmaris"),
    "mugla-fethiye": ("mugla", "Fethiye"), "mugla-bodrum": ("mugla", "Bodrum"),
    "mugla-koycegiz": ("mugla", "Köyceğiz"), "mugla-milas": ("mugla", "Milas"),
    "antalya-finike": ("antalya", "Finike"), "antalya-konyaalti": ("antalya", "Konyaaltı"),
    "antalya-kas": ("antalya", "Kaş"), "antalya-kemer": ("antalya", "Kemer"),
    "antalya-alanya": ("antalya", "Alanya"), "mersin-yenisehir": ("mersin", "Yenişehir"),
    "antalya-gazipasa": ("antalya", "Gazipaşa"), "mersin-erdemli": ("mersin", "Erdemli"),
    "izmir-balcova": ("izmir", "Balçova"), "izmir-foca": ("izmir", "Foça"),
    "canakkale-merkez": ("canakkale", "Merkez"), "canakkale-gelibolu": ("canakkale", "Gelibolu"),
    "balikesir-erdek": ("balikesir", "Erdek"), "bursa-mudanya": ("bursa", "Mudanya"),
    "istanbul-sariyer": ("istanbul", "Sarıyer"), "antalya-muratpasa": ("antalya", "Muratpaşa"),
    "antalya-demre": ("antalya", "Demre"), "mersin-silifke": ("mersin", "Silifke"),
    "mugla-datca": ("mugla", "Datça"), "mugla-ula": ("mugla", "Ula"),
    "istanbul-beykoz": ("istanbul", "Beykoz"), "istanbul-adalar": ("istanbul", "Adalar"),
    "istanbul-buyukcekmece": ("istanbul", "Büyükçekmece"),
    "balikesir-marmara": ("balikesir", "Marmara"), "balikesir-bandirma": ("balikesir", "Bandırma"),
    "balikesir-burhaniye": ("balikesir", "Burhaniye"), "canakkale-biga": ("canakkale", "Biga"),
    "canakkale-bozcaada": ("canakkale", "Bozcaada"), "canakkale-gokceada": ("canakkale", "Gökçeada"),
    "canakkale-ayvacik": ("canakkale", "Ayvacık"), "tekirdag-sarkoy": ("tekirdag", "Şarköy"),
    "izmir-dikili": ("izmir", "Dikili"), "izmir-karaburun": ("izmir", "Karaburun"),
    "izmir-urla": ("izmir", "Urla"), "izmir-menderes": ("izmir", "Menderes"),
    "aydin-soke": ("aydin", "Söke"),
    "istanbul-maltepe": ("istanbul", "Maltepe"), "istanbul-silivri": ("istanbul", "Silivri"),
    "mersin-aydincik": ("mersin", "Aydıncık"), "mersin-anamur": ("mersin", "Anamur"),
    "mersin-gulnar": ("mersin", "Gülnar"),
    "kocaeli-izmit": ("kocaeli", "İzmit"), "kocaeli-gebze": ("kocaeli", "Gebze"),
    "kocaeli-darica": ("kocaeli", "Darıca"), "kocaeli-korfez": ("kocaeli", "Körfez"),
    "kocaeli-karamursel": ("kocaeli", "Karamürsel"),
    "antalya-kumluca": ("antalya", "Kumluca"), "balikesir-edremit": ("balikesir", "Edremit"),
}


GR_PROVINCES = {
    "gr-korfu": "Korfu", "gr-preveza": "Preveza", "gr-lefkada": "Lefkada",
    "gr-mesolongi": "Mesolongi", "gr-kalamata": "Kalamata", "gr-atina": "Atina",
    "gr-selanik": "Selanik", "gr-halkidiki": "Halkidiki", "gr-midilli": "Midilli",
    "gr-samos": "Samos", "gr-leros": "Leros", "gr-kos": "Kos", "gr-rodos": "Rodos",
    "gr-symi": "Symi", "gr-meis": "Meis (Kastellorizo)", "gr-tilos": "Tilos",
    "gr-halki": "Halki (Herke)", "gr-kalymnos": "Kalymnos", "gr-patmos": "Patmos",
    "gr-nisyros": "Nisyros", "gr-lipsi": "Lipsi", "gr-sakiz": "Sakız (Chios)",
    "gr-fourni": "Fourni", "gr-amorgos": "Amorgos", "gr-naxos": "Naxos", "gr-paros": "Paros",
    "gr-syros": "Syros", "gr-mykonos": "Mykonos", "gr-kefalonya": "Kefalonya", "gr-zakinthos": "Zakynthos", "gr-girit": "Girit",
    "gr-agathonisi": "Agathonisi", "gr-astypalaia": "Astypalaia",
    "gr-egina": "Egina (Aegina)", "gr-hydra": "İdra (Hydra)", "gr-spetses": "Spetses",
    "gr-poros": "Poros", "gr-ikarya": "İkarya (Ikaria)", "gr-milos": "Milos",
    "gr-santorini": "Santorini (Thira)", "gr-paksos": "Paksos (Paxoi)",
}

# slug → ülke (validasyon + emit için)
PROV_COUNTRY = {**{k: "TR" for k in PROVINCES}, **{k: "GR" for k in GR_PROVINCES}}


def q(value):
    """SQL string literal (tek tırnak kaçışı); None → NULL."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def num(value):
    return "NULL" if value is None else str(value)


def norm_name(name):
    n = unicodedata.normalize("NFKD", name.lower())
    return re.sub(r"[^a-z0-9]", "", n)


def validate(records):
    errors, warnings = [], []
    slugs, names = set(), {}
    for r in records:
        s = r["slug"]
        if s in slugs:
            errors.append(f"Mükerrer slug: {s}")
        slugs.add(s)
        key = norm_name(r["name"])
        if key in names:
            warnings.append(f"İsim benzerliği (mükerrer olabilir): {r['name']} ~ {names[key]}")
        names[key] = r["name"]
        if r["typeCode"] not in TYPE_IDS:
            errors.append(f"{s}: bilinmeyen typeCode {r['typeCode']}")
        country = r.get("countryCode", "TR")
        if country not in COUNTRY_BOUNDS:
            errors.append(f"{s}: bilinmeyen countryCode {country}")
        else:
            (lat_lo, lat_hi), (lon_lo, lon_hi) = COUNTRY_BOUNDS[country]
            if not (lat_lo <= r["lat"] <= lat_hi) or not (lon_lo <= r["lon"] <= lon_hi):
                errors.append(f"{s}: koordinat {country} kutusu dışında ({r['lat']}, {r['lon']})")
        for a in r.get("amenities", []):
            if a not in AMENITIES:
                errors.append(f"{s}: geçersiz amenity kodu '{a}'")
        for sv in r.get("services", []):
            if sv not in SERVICES:
                errors.append(f"{s}: geçersiz service kodu '{sv}'")
        for c in r.get("contacts", []):
            if c["type"] not in CONTACT_TYPES:
                errors.append(f"{s}: geçersiz contact tipi '{c['type']}'")
            if c["type"] in ("phone", "whatsapp") and not re.fullmatch(r"\+(90|30)\d{10}", c["value"]):
                warnings.append(f"{s}: telefon biçimi normalize değil: {c['value']}")
        if r.get("holdingType") is not None and r["holdingType"] not in HOLDING_TYPES:
            errors.append(f"{s}: geçersiz holdingType '{r['holdingType']}' (izinli: {sorted(HOLDING_TYPES)})")
        if r["status"] not in ("published", "draft"):
            errors.append(f"{s}: geçersiz status {r['status']}")
        if r.get("districtSlug") and r["districtSlug"] not in DISTRICTS:
            errors.append(f"{s}: tanımsız districtSlug {r['districtSlug']}")
        prov = r.get("provinceSlug")
        if prov not in PROV_COUNTRY:
            errors.append(f"{s}: tanımsız provinceSlug {prov}")
        elif PROV_COUNTRY[prov] != r.get("countryCode", "TR"):
            errors.append(f"{s}: provinceSlug {prov} ile countryCode uyuşmuyor")
    return errors, warnings


def emit(records, batch_meta):
    out = []
    out.append("-- =========================================================================")
    out.append("-- Dockly — Gerçek lokasyon verisi (Faz 5 veri edinimi)")
    out.append(f"-- Parti: {batch_meta['batch']} · Toplama: {batch_meta['collectedAt']}")
    out.append("-- Kaynak ve güven bilgisi: prisma/data/batch1_marinas.json (provenance)")
    out.append("-- Bu dosya generate_locations_seed.py ile üretilir; ELLE DÜZENLEME.")
    out.append("-- Tamamen idempotent: CI seed'i iki kez koşar (ON CONFLICT DO NOTHING).")
    out.append("-- =========================================================================")
    out.append("")
    out.append("-- --- Ülke aktivasyonu (GR kayıtları varsa) ---")
    if any(r.get("countryCode", "TR") == "GR" for r in records):
        out.append("UPDATE countries SET is_active = true WHERE code = 'GR';")
    out.append("")
    out.append("-- --- İdari alanlar (il/ilçe) ---")
    for slug, name in PROVINCES.items():
        out.append(
            "INSERT INTO admin_areas (id, country_code, level, name, slug)\n"
            f"VALUES (gen_random_uuid(), 'TR', 'province', {q(name)}, {q(slug)})\n"
            "ON CONFLICT (country_code, level, slug) DO NOTHING;"
        )
    for slug, name in GR_PROVINCES.items():
        out.append(
            "INSERT INTO admin_areas (id, country_code, level, name, slug)\n"
            f"VALUES (gen_random_uuid(), 'GR', 'province', {q(name)}, {q(slug)})\n"
            "ON CONFLICT (country_code, level, slug) DO NOTHING;"
        )
    out.append("")
    for slug, (prov, name) in DISTRICTS.items():
        out.append(
            "INSERT INTO admin_areas (id, country_code, parent_id, level, name, slug)\n"
            f"SELECT gen_random_uuid(), 'TR', p.id, 'district', {q(name)}, {q(slug)}\n"
            f"FROM admin_areas p WHERE p.country_code = 'TR' AND p.level = 'province' AND p.slug = {q(prov)}\n"
            "ON CONFLICT (country_code, level, slug) DO NOTHING;"
        )
    out.append("")
    for r in records:
        s = r["slug"]
        country = r.get("countryCode", "TR")
        admin_slug = r.get("districtSlug") or r.get("provinceSlug")
        admin_level = "district" if r.get("districtSlug") else "province"
        src = ", ".join(u.split("/")[2] for u in r.get("sourceUrls", [])[:2])
        out.append(f"-- --- {r['name']} · güven: {r['confidence']} · kaynak: {src} ---")
        out.append(
            "INSERT INTO locations (id, slug, location_type_id, status, country_code, admin_area_id,\n"
            "  name, description, position, max_boat_length_m, max_draft_m, depth_min_m, depth_max_m,\n"
            "  capacity, price_tier, source)\n"
            f"SELECT gen_random_uuid(), {q(s)}, {TYPE_IDS[r['typeCode']]}, {q(r['status'])}, {q(country)},\n"
            f"  (SELECT id FROM admin_areas WHERE country_code = {q(country)} AND level = {q(admin_level)} AND slug = {q(admin_slug)}),\n"
            f"  {q(r['name'])}, {q(r.get('descriptionTr'))},\n"
            f"  ST_SetSRID(ST_MakePoint({r['lon']}, {r['lat']}), 4326)::geography,\n"
            f"  {num(r.get('maxLoaM'))}, {num(r.get('maxDraftM'))}, {num(r.get('depthMinM'))}, {num(r.get('depthMaxM'))},\n"
            f"  {num(r.get('berthCount'))}, {q(r.get('priceTier', 'paid'))}, 'import'\n"
            "ON CONFLICT (slug) DO NOTHING;"
        )
        out.append(
            "INSERT INTO location_i18n (location_id, locale, name, description)\n"
            f"SELECT id, 'tr', {q(r['name'])}, {q(r.get('descriptionTr'))} FROM locations WHERE slug = {q(s)}\n"
            # İçerik = kod: ad/açıklama düzeltmeleri canlıya AKMALI → DO UPDATE.
            # Idempotent kalır (aynı girdi ikinci kez koşunca aynı sonuç).
            "ON CONFLICT (location_id, locale) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;"
        )
        is_marina = r["typeCode"] in ("private_marina", "municipal_marina")
        blue = "NULL" if r.get("blueFlag") is None else ("true" if r["blueFlag"] else "false")
        winter = "NULL" if r.get("winterStorage") is None else ("true" if r["winterStorage"] else "false")
        if is_marina: out.append(
            "INSERT INTO marina_details (location_id, berth_count, vhf_channel, has_blue_flag,\n"
            "  travel_lift_capacity_tons, winter_storage)\n"
            f"SELECT id, {num(r.get('berthCount'))}, {q(r.get('vhfChannel'))}, {blue}, {num(r.get('travelLiftTons'))}, {winter}\n"
            f"FROM locations WHERE slug = {q(s)}\n"
            "ON CONFLICT (location_id) DO NOTHING;"
        )
        if r["typeCode"] in ("mooring_point", "guest_mooring", "buoy") and (
            r.get("holdingType") is not None or r.get("swellExposure") is not None or r.get("isFree") is not None
        ):
            freev = "true" if r.get("isFree", True) else "false"
            out.append(
                "INSERT INTO anchorage_details (location_id, holding_type, swell_exposure, is_free)\n"
                f"SELECT id, {q(r.get('holdingType'))}, {q(r.get('swellExposure'))}, {freev}\n"
                f"FROM locations WHERE slug = {q(s)}\n"
                "ON CONFLICT (location_id) DO NOTHING;"
            )
        if r["typeCode"] == "restaurant_pier":
            resv = "NULL" if r.get("reservationRecommended") is None else ("true" if r["reservationRecommended"] else "false")
            out.append(
                "INSERT INTO restaurant_dock_details (location_id, cuisine, berth_count_free, min_spend_policy, reservation_recommended)\n"
                f"SELECT id, {q(r.get('cuisine'))}, {num(r.get('berthCount'))}, {q(r.get('minSpendPolicy'))}, {resv}\n"
                f"FROM locations WHERE slug = {q(s)}\n"
                "ON CONFLICT (location_id) DO NOTHING;"
            )
        if r["typeCode"] == "fuel_pier":
            def b3(v):
                return "NULL" if v is None else ("true" if v else "false")
            out.append(
                "INSERT INTO fuel_dock_details (location_id, has_diesel, has_gasoline, has_adblue, min_depth_m, payment_note)\n"
                f"SELECT id, {b3(r.get('hasDiesel'))}, {b3(r.get('hasGasoline'))}, {b3(r.get('hasAdblue'))}, {num(r.get('fuelMinDepthM'))}, {q(r.get('paymentNote'))}\n"
                f"FROM locations WHERE slug = {q(s)}\n"
                "ON CONFLICT (location_id) DO NOTHING;"
            )
        if r.get("amenities"):
            codes = ", ".join(q(a) for a in r["amenities"])
            out.append(
                "INSERT INTO location_amenities (location_id, amenity_id)\n"
                f"SELECT l.id, a.id FROM locations l, amenities a\n"
                f"WHERE l.slug = {q(s)} AND a.code IN ({codes})\n"
                "ON CONFLICT DO NOTHING;"
            )
        if r.get("services"):
            codes = ", ".join(q(sv) for sv in r["services"])
            out.append(
                "INSERT INTO location_services (location_id, service_id)\n"
                f"SELECT l.id, sv.id FROM locations l, services sv\n"
                f"WHERE l.slug = {q(s)} AND sv.code IN ({codes})\n"
                "ON CONFLICT DO NOTHING;"
            )
        for c in r.get("contacts", []):
            primary = "true" if c.get("primary") else "false"
            out.append(
                "INSERT INTO location_contacts (id, location_id, contact_type, value, label, is_primary)\n"
                f"SELECT gen_random_uuid(), l.id, {q(c['type'])}, {q(c['value'])}, {q(c.get('label'))}, {primary}\n"
                f"FROM locations l WHERE l.slug = {q(s)}\n"
                "ON CONFLICT (location_id, contact_type, value) DO NOTHING;"
            )
        season = r.get("season")
        if season:
            om, od = season["opensOn"]
            cm, cd = season["closesOn"]
            out.append(
                "INSERT INTO opening_seasons (id, location_id, opens_on_month, opens_on_day, closes_on_month, closes_on_day)\n"
                f"SELECT gen_random_uuid(), l.id, {om}, {od}, {cm}, {cd} FROM locations l\n"
                f"WHERE l.slug = {q(s)}\n"
                "  AND NOT EXISTS (SELECT 1 FROM opening_seasons os WHERE os.location_id = l.id)\n"
                ";"
            )
        out.append("")
    return "\n".join(out) + "\n"



def emit_demirleme(here, records):
    """DEMİRLEME BİLGİLERİ TURU (2026-08): zemin/derinlik, izinli kaynaklardan
    birebir alıntıyla toplandı ve tamamı elle doğrulandı
    (data/demirleme_bilgileri.json — kaynak URL'leri dosyada).
    Yalnız BOŞ alanları doldurur (COALESCE) — batch verisi asla ezilmez.

    is_free KURALI (CI dersi, 2026-08): kolon şemada NOT NULL DEFAULT true —
    NULL yazmak yasak (constraint ihlali, seed kırmızısı). Bu yüzden is_free
    kolonu INSERT'e hiç yazılmaz: yeni satır şema varsayılanını alır (batch
    ekleyicisiyle aynı davranış), MEVCUT satırların değeri asla değişmez.
    Sahte "ücretsiz" rozeti riski yok: gerçek demirleme koylarında
    "demirleme ücretsizdir" şemanın kendi varsayılanıdır.

    TİP KURALI (CI dersi #2, 2026-08): DB tetikleyicisi
    trg_check_anchorage_details_type anchorage_details'i YALNIZ
    mooring_point/buoy/guest_mooring tipli location'lara izin verir.
    Bu yüzden zemin SQL'i yalnız bu tiplere yazılır; diğer tiplerdeki
    (ör. restoran iskelesi) zemin bulguları JSON arşivinde kalır ve
    üretici bunları raporlayıp ATLAR — derinlik bulguları ise locations
    tablosuna gittiği için HER tipte işlenir.
    UPDATE/UPSERT kullanılır ki mevcut canlı satırlara da aksın (idempotent)."""
    path = here / "demirleme_bilgileri.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    slugs = {r["slug"] for r in records}
    type_by_slug = {r["slug"]: r["typeCode"] for r in records}
    ANCHORAGE_TYPES = {"mooring_point", "buoy", "guest_mooring"}
    errors = []
    for slug, v in sorted(data["veriler"].items()):
        if slug not in slugs:
            errors.append(f"demirleme: bilinmeyen slug '{slug}'")
        z = v.get("zemin")
        if z is not None and z not in HOLDING_TYPES:
            errors.append(f"demirleme {slug}: geçersiz zemin '{z}' (izinli: {sorted(HOLDING_TYPES)})")
        dmin, dmax = v.get("derinlik_min"), v.get("derinlik_max")
        for d in (dmin, dmax):
            if d is not None and not (0 < float(d) <= 60):
                errors.append(f"demirleme {slug}: mantıksız derinlik {d}")
        if dmin is not None and dmax is not None and float(dmin) > float(dmax):
            errors.append(f"demirleme {slug}: derinlik_min > derinlik_max")
        if z is None and dmin is None and dmax is None:
            errors.append(f"demirleme {slug}: boş kayıt")
    if errors:
        for e in errors:
            print("HATA:", e)
        sys.exit(1)
    out = [
        "",
        "-- =====================================================================",
        "-- DEMİRLEME BİLGİLERİ (2026-08 turu — birebir alıntılı, elle doğrulandı)",
        "-- =====================================================================",
    ]
    kurtarilan = []
    for slug, v in sorted(data["veriler"].items()):
        dmin, dmax = v.get("derinlik_min"), v.get("derinlik_max")
        if dmin is not None or dmax is not None:
            out.append(
                f"UPDATE locations SET depth_min_m = COALESCE(depth_min_m, {num(dmin)}), "
                f"depth_max_m = COALESCE(depth_max_m, {num(dmax)}) WHERE slug = {q(slug)};"
            )
        if v.get("zemin") is not None:
            if type_by_slug.get(slug) not in ANCHORAGE_TYPES:
                # DB tetikleyicisi bu tipe anchorage satırı YASAKLAR (CI dersi
                # #2). 0009_seabed'e kadar bu bulgular JSON arşivinde kalıyor,
                # hiçbir yere yazılamıyordu; artık locations.seabed_holding_type
                # sütununa akıyorlar — kaptan restoran iskelesinde de dibin
                # cinsini görüyor, "Ücretsiz" rozeti riski doğmuyor.
                kurtarilan.append(slug)
                out.append(
                    "UPDATE locations SET seabed_holding_type = "
                    f"COALESCE(seabed_holding_type, {q(v['zemin'])}) WHERE slug = {q(slug)};"
                )
                continue
            out.append(
                # is_free BİLEREK yok: NOT NULL DEFAULT true — NULL yazılamaz;
                # yeni satır şema varsayılanını alır, mevcut satıra dokunulmaz.
                "INSERT INTO anchorage_details (location_id, holding_type, swell_exposure)\n"
                f"SELECT id, {q(v['zemin'])}, NULL FROM locations WHERE slug = {q(slug)}\n"
                "ON CONFLICT (location_id) DO UPDATE SET holding_type = "
                "COALESCE(anchorage_details.holding_type, EXCLUDED.holding_type);"
            )
    if kurtarilan:
        print(f"demirleme: {len(kurtarilan)} zemin locations.seabed_holding_type'a "
              "yazıldı (demirleme dışı tip): " + ", ".join(kurtarilan))
    print(f"demirleme: {len(data['veriler'])} nokta işlendi")
    return "\n".join(out) + "\n"


def emit_yapilandirma(here, records):
    """AÇIKLAMADAN YAPILANDIRMA TURU (2026-08): yeni araştırma YOK.

    Bu bölümdeki her değer, veri tabanındaki KENDİ kayıtlı açıklamamızın
    içinde zaten geçen ve kaynağı daha önce doğrulanmış bir cümleden
    yapılandırıldı (JSON'daki 'alinti' alanı o cümlenin birebir kopyası,
    'kaynak' alanı o cümlenin geldiği kaydın URL'i). Serbest metinde saklı
    bilgi, aranabilir/filtrelenebilir kolonlara taşınır.

    ZEMİN NEREYE YAZILIR: demirleme tiplerinde (mooring_point/buoy/
    guest_mooring) tarihsel yer olan anchorage_details.holding_type'a;
    diğer tiplerde (balıkçı barınağı, belediye limanı, marina, restoran
    iskelesi) locations.seabed_holding_type sütununa (0009_seabed).
    Tetikleyici trg_anchorage_details_check_type o tablolara barınak satırı
    yazdırmadığı için ikinci yol açıldı; API iki kaynağı birleştirir.

    Yalnız BOŞ alanlar doldurulur (COALESCE) — mevcut veri asla ezilmez.
    """
    f = here / "aciklamadan_yapilandirma_2026_08.json"
    if not f.exists():
        return ""
    data = json.loads(f.read_text(encoding="utf-8"))["veriler"]
    slugs = {r["slug"] for r in records}
    type_by_slug = {r["slug"]: r["typeCode"] for r in records}
    ANCHORAGE_TYPES = {"mooring_point", "buoy", "guest_mooring"}
    errors = []
    for slug, v in sorted(data.items()):
        if slug not in slugs:
            errors.append(f"yapilandirma: bilinmeyen slug {slug}")
            continue
        z = v.get("zemin")
        if z is not None and z not in HOLDING_TYPES:
            errors.append(f"yapilandirma {slug}: gecersiz zemin {z}")
        dmin, dmax = v.get("derinlik_min"), v.get("derinlik_max")
        for d in (dmin, dmax):
            if d is not None and not (0 < float(d) <= 60):
                errors.append(f"yapilandirma {slug}: mantiksiz derinlik {d}")
        if dmin is not None and dmax is not None and float(dmin) > float(dmax):
            errors.append(f"yapilandirma {slug}: derinlik_min > derinlik_max")
        if z is None and dmin is None and dmax is None:
            errors.append(f"yapilandirma {slug}: bos kayit")
        # Kaynak zinciri zorunlu: alintisiz/kaynaksiz deger bu turda YASAK.
        if not v.get("alinti"):
            errors.append(f"yapilandirma {slug}: alinti yok")
        if not v.get("kaynak"):
            errors.append(f"yapilandirma {slug}: kaynak yok")
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    out = ["", "-- " + "=" * 70,
           "-- ACIKLAMADAN YAPILANDIRMA (2026-08) — kendi kaynakli metnimizden",
           "-- cikarilan zemin/derinlik; yeni arastirma yok, yalnizca bos alanlar."]
    n_z = n_d = 0
    for slug, v in sorted(data.items()):
        dmin, dmax = v.get("derinlik_min"), v.get("derinlik_max")
        if dmin is not None or dmax is not None:
            n_d += 1
            out.append(
                f"UPDATE locations SET depth_min_m = COALESCE(depth_min_m, {num(dmin)}), "
                f"depth_max_m = COALESCE(depth_max_m, {num(dmax)}) WHERE slug = {q(slug)};"
            )
        z = v.get("zemin")
        if z is not None:
            n_z += 1
            if type_by_slug.get(slug) in ANCHORAGE_TYPES:
                out.append(
                    "INSERT INTO anchorage_details (location_id, holding_type, swell_exposure)\n"
                    f"SELECT id, {q(z)}, NULL FROM locations WHERE slug = {q(slug)}\n"
                    "ON CONFLICT (location_id) DO UPDATE SET holding_type = "
                    "COALESCE(anchorage_details.holding_type, EXCLUDED.holding_type);"
                )
            else:
                out.append(
                    "UPDATE locations SET seabed_holding_type = "
                    f"COALESCE(seabed_holding_type, {q(z)}) WHERE slug = {q(slug)};"
                )
    print(f"yapilandirma: {n_z} zemin + {n_d} derinlik islendi")
    out.append("")
    return "\n".join(out)


def emit_i18n(here, records):
    """Veri çevirileri (i18n_*.json) → location_i18n satırları (idempotent).

    Kullanıcı kararı (2026-07): koy/liman ADLARI ÇEVRİLMEZ — yalnız açıklama.
    Bu yüzden name hep NULL yazılır ve DO UPDATE yalnız description'ı tazeler;
    böylece i18n satırı ad zincirini (istenen → en → taban ad) bozamaz.
    Dosya biçimi: {"round": "...", "translations": {"<slug>": {"en": "...",
    "es": "...", "ru": "..."}}}. Tutarlılık kuralları:
    - slug kayıtlarda bulunmalı (çeviri sahipsiz kalamaz),
    - locale yalnız en/es/ru (tr ana bölümden gelir),
    - metin boş olamaz; rakamlar TR kaynakla AYNI kalmalı (derinlik, VHF,
      telefon vb. çeviride değişemez — 0 uydurma veri ilkesinin uzantısı).
    """
    files = sorted(here.glob("i18n_*.json"))
    if not files:
        return ""
    by = {r["slug"]: r for r in records}
    out = ["", "-- " + "=" * 70,
           "-- VERİ ÇEVİRİLERİ — koy açıklamaları EN/ES/RU (adlar çevrilmez).",
           "-- Kaynak: i18n_*.json; yeniden koşmak çeviriyi tazeler (DO UPDATE)."]
    errors = []
    digits = lambda t: sorted(re.findall(r"\d+(?:[.,]\d+)?", t or ""))
    for f in files:
        data = json.loads(f.read_text(encoding="utf-8"))
        out.append(f"-- --- {f.name} ({data.get('round', '?')}) ---")
        for slug, tr_map in data["translations"].items():
            r = by.get(slug)
            if r is None:
                errors.append(f"i18n {f.name}: bilinmeyen slug {slug}")
                continue
            src_digits = digits(r.get("descriptionTr"))
            for locale in sorted(tr_map):
                text = tr_map[locale]
                if locale not in ("en", "es", "ru"):
                    errors.append(f"i18n {slug}: geçersiz locale {locale}")
                    continue
                if not isinstance(text, str) or not text.strip():
                    errors.append(f"i18n {slug}/{locale}: boş çeviri")
                    continue
                if digits(text) != src_digits:
                    errors.append(
                        f"i18n {slug}/{locale}: rakamlar TR kaynakla uyuşmuyor "
                        f"(TR={src_digits} ≠ {digits(text)})")
                out.append(
                    "INSERT INTO location_i18n (location_id, locale, name, description)\n"
                    f"SELECT id, {q(locale)}, NULL, {q(text)} FROM locations WHERE slug = {q(slug)}\n"
                    "ON CONFLICT (location_id, locale) DO UPDATE SET description = EXCLUDED.description;"
                )
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    out.append("")
    return "\n".join(out)


def emit_yaklasma(here, records):
    """Yaklaşma/tehlike notları → açıklamalara (4 dil) eklenir (2026-08).

    Kaynak zinciri: yaklasma_notlari.json = birebir alıntı + URL arşivi
    (doğrulanmış bulgular); yaklasma_i18n.json = oradan derlenen ekran
    metinleri (TR) + EN/ES/RU çevirileri. Bu üretici:
      locations.description        = taban TR + "\\n\\n" + "Yaklaşma notu: " + not
      location_i18n tr/en/es/ru    = taban çeviri + ön ek + notun çevirisi
    TAM DEĞİŞTİRME yazar (append değil) → yeniden koşmak idempotenttir.
    emit_i18n'den SONRA koşmalıdır: en/es/ru taban çevirilerinin üzerine
    notlu birleşik metni yazar (aksi hâlde taban çeviri notu ezerdi).
    Kurallar: slug hem arşivde hem kayıtlarda olmalı; 4 dil de dolu olmalı;
    rakamlar dört dilde AYNI olmalı (ondalık , ve . eşdeğer — 0 uydurma
    ilkesinin uzantısı); TR metin arşivdeki nottan türemiş olmalı."""
    f = here / "yaklasma_i18n.json"
    if not f.exists():
        return ""
    display = json.loads(f.read_text(encoding="utf-8"))["metinler"]
    arsiv = json.loads((here / "yaklasma_notlari.json").read_text(encoding="utf-8"))["notlar"]
    by = {r["slug"]: r for r in records}
    # Taban çeviriler: emit_i18n ile aynı kaynak ve aynı öncelik (son dosya kazanır).
    base_i18n = {}
    for jf in sorted(here.glob("i18n_*.json")):
        for slug, tr_map in json.loads(jf.read_text(encoding="utf-8"))["translations"].items():
            base_i18n.setdefault(slug, {}).update(tr_map)
    PREFIX = {"tr": "Yaklaşma notu: ", "en": "Approach note: ",
              "es": "Nota de aproximación: ", "ru": "Заметка о подходе: "}
    norm_digits = lambda t: sorted(
        d.replace(",", ".") for d in re.findall(r"\d+(?:[.,]\d+)?", t or ""))
    errors = []
    out = ["", "-- " + "=" * 70,
           "-- YAKLAŞMA NOTLARI — açıklamalara eklenir (4 dil, tam-değiştirme).",
           "-- Kaynak: yaklasma_notlari.json (alıntı+URL) → yaklasma_i18n.json."]
    for slug, texts in sorted(display.items()):
        r = by.get(slug)
        if r is None:
            errors.append(f"yaklasma {slug}: kayıtlarda yok"); continue
        if slug not in arsiv:
            errors.append(f"yaklasma {slug}: arşivde (yaklasma_notlari.json) yok"); continue
        tr_text = texts.get("tr", "")
        # TR ekran metni arşivdeki nottan türemiş olmalı (ilk harf büyütme
        # serbest — karşılaştırma ilk karakter atlanarak yapılır).
        if not (tr_text and (tr_text in arsiv[slug]["not"] or tr_text[1:] in arsiv[slug]["not"])):
            errors.append(f"yaklasma {slug}: TR metin arşiv notundan türememiş")
        base_tr = r.get("descriptionTr")
        if not base_tr:
            errors.append(f"yaklasma {slug}: taban TR açıklama yok"); continue
        if PREFIX["tr"] in base_tr:
            errors.append(f"yaklasma {slug}: taban açıklama zaten not içeriyor (çift ekleme)")
        for locale in ("tr", "en", "es", "ru"):
            text = texts.get(locale)
            if not isinstance(text, str) or not text.strip():
                errors.append(f"yaklasma {slug}/{locale}: boş metin"); continue
            if norm_digits(text) != norm_digits(tr_text):
                errors.append(
                    f"yaklasma {slug}/{locale}: rakamlar TR ile uyuşmuyor "
                    f"({norm_digits(tr_text)} ≠ {norm_digits(text)})")
        if errors:
            continue
        combined = {"tr": f"{base_tr}\n\n{PREFIX['tr']}{tr_text}"}
        for locale in ("en", "es", "ru"):
            # Taban çeviri varsa onun üstüne; yoksa TR taban + yerel not (uyarı
            # güvenlik-kritik olduğu için her dilde mutlaka yerelleşir).
            base_loc = base_i18n.get(slug, {}).get(locale) or base_tr
            combined[locale] = f"{base_loc}\n\n{PREFIX[locale]}{texts[locale]}"
        out.append(f"-- --- {slug} ---")
        out.append(
            f"UPDATE locations SET description = {q(combined['tr'])} WHERE slug = {q(slug)};")
        for locale in ("tr", "en", "es", "ru"):
            out.append(
                "INSERT INTO location_i18n (location_id, locale, name, description)\n"
                f"SELECT id, {q(locale)}, NULL, {q(combined[locale])} FROM locations WHERE slug = {q(slug)}\n"
                "ON CONFLICT (location_id, locale) DO UPDATE SET description = EXCLUDED.description;"
            )
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"yaklasma: {len(display)} nokta 4 dilde açıklamalara işlendi")
    out.append("")
    return "\n".join(out)


def emit_wind(here, records):
    """Rüzgâra açık yönler (ruzgar_yonleri.json) → locations.wind_exposed_dirs.

    Açıklamalardaki doğrulanmış ifadelerden türetilmiş, elle gözden geçirilmiş
    veridir. UPDATE kullanılır ki mevcut canlı satırlara da AKSIN (idempotent).
    locations tablosunda tutulur — her türe (koy, liman, marina) uygulanır,
    yan etkisizdir.
    """
    f = here / "ruzgar_yonleri.json"
    if not f.exists():
        return ""
    data = json.loads(f.read_text(encoding="utf-8"))["yonler"]
    by = {r["slug"] for r in records}
    out = ["", "-- " + "=" * 70,
           "-- RÜZGÂRA AÇIK YÖNLER — uyarı rozeti verisi (açıklamalardan, elle onaylı)."]
    errors = []
    GECERLI = {"K", "KD", "D", "GD", "G", "GB", "B", "KB"}
    for slug, dirs in sorted(data.items()):
        if slug not in by:
            errors.append(f"rüzgâr: bilinmeyen slug {slug}")
            continue
        bad = [x for x in dirs if x not in GECERLI]
        if bad:
            errors.append(f"rüzgâr {slug}: geçersiz yön {bad}")
            continue
        csv = ",".join(dirs)
        out.append(
            f"UPDATE locations SET wind_exposed_dirs = {q(csv)} WHERE slug = {q(slug)};"
        )
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    out.append("")
    return "\n".join(out)


def emit_korunak(here, records):
    """RÜZGÂR KORUNAĞI TURU (2026-08) → locations.wind_sheltered_dirs.

    DİKKAT — BU ALAN `wind_exposed_dirs` DEĞİLDİR ve onun tersi de değildir.
    Kılavuzlar korunağı ayrı yazar ("provides good shelter from northerly
    winds", "kuzey rüzgârlarına kapalı"). "Kuzeyden korunaklı" ifadesi
    "güneye açık" DEMEK DEĞİLDİR: koy doğuya da açık olabilir, hiçbir yöne
    açık olmayabilir. Bu yüzden korunak ifadesi ASLA wind_exposed_dirs'e
    çevrilmez — çevrilseydi arayüz kaptana tam tersini gösterirdi.

    Sekiz yönün TAMAMI = kaynak "all round shelter" demiştir; arayüz bunu
    "Her yönden" etiketine indirir. Kısmi liste yazılmayan yönlerin AÇIK
    olduğu anlamına gelmez, yalnızca kaynağın sustuğu anlamına gelir.

    Yalnız BOŞ alan doldurulur (COALESCE); mevcut veri asla ezilmez.
    """
    f = here / "ruzgar_korunak_2026_08.json"
    if not f.exists():
        return ""
    data = json.loads(f.read_text(encoding="utf-8"))["veriler"]
    slugs = {r["slug"] for r in records}
    GECERLI = ["K", "KD", "D", "GD", "G", "GB", "B", "KB"]
    # ÇELİŞKİ NÖBETÇİSİ: aynı nokta bir yöne hem "açık" hem "korunaklı"
    # olamaz. Bugün iki küme ayrık, ama ileride biri diğerine dokunursa
    # detay sayfası "Açık yön: G" ile "Kapalı yön: G" yan yana çıkardı.
    wf = here / "ruzgar_yonleri.json"
    acik = json.loads(wf.read_text(encoding="utf-8"))["yonler"] if wf.exists() else {}
    errors = []
    for slug, v in sorted(data.items()):
        if slug not in slugs:
            errors.append(f"korunak: bilinmeyen slug {slug}")
            continue
        dirs = v.get("yonler") or []
        bad = [x for x in dirs if x not in GECERLI]
        if bad:
            errors.append(f"korunak {slug}: gecersiz yon {bad}")
        if len(set(dirs)) != len(dirs):
            errors.append(f"korunak {slug}: yon tekrari")
        if not dirs:
            errors.append(f"korunak {slug}: bos kayit")
        # Kaynak zinciri zorunlu: alintisiz deger bu turda YASAK.
        if not v.get("alinti"):
            errors.append(f"korunak {slug}: alinti yok")
        if not v.get("kaynak"):
            errors.append(f"korunak {slug}: kaynak yok")
        # "tam_korunak" iddiasi ile 8 yon birbirini tutmali.
        tam = bool(v.get("tam_korunak"))
        if tam != (len(set(dirs)) == 8):
            errors.append(f"korunak {slug}: tam_korunak bayragi 8 yon ile tutarsiz")
        cakisan = sorted(set(dirs) & set(acik.get(slug, [])))
        if cakisan:
            errors.append(
                f"korunak {slug}: {cakisan} yonu hem acik hem korunakli yazilmis")
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    out = ["", "-- " + "=" * 70,
           "-- RUZGAR KORUNAGI (2026-08 kaynak turu) — KORUNAKLI yonler.",
           "-- Bu alan wind_exposed_dirs'in TERSI DEGILDIR; kilavuz cumlesinden",
           "-- birebir alindi. Sekiz yon = kaynak 'all round shelter' demistir."]
    for slug, v in sorted(data.items()):
        # Kanonik sira: pusula sirasi (K'dan saat yonunde) — kayit sirasi degil.
        csv = ",".join([d for d in GECERLI if d in v["yonler"]])
        out.append(
            "UPDATE locations SET wind_sheltered_dirs = "
            f"COALESCE(wind_sheltered_dirs, {q(csv)}) WHERE slug = {q(slug)};"
        )
    print(f"korunak: {len(data)} nokta islendi")
    out.append("")
    return "\n".join(out)


def emit_corrections(here, records):
    """Doğrulama turu düzeltmeleri (corrections_*.json) → idempotent SQL.

    Ana bölüm ON CONFLICT DO NOTHING olduğundan, MEVCUT veritabanlarındaki
    eski/teyitsiz iletişim satırları ve durum değişiklikleri oraya AKMAZ;
    bu bölüm onları açıkça siler/günceller. Tutarlılık kuralları:
    - slug kayıtlarda bulunmalı,
    - silinen değer JSON'daki güncel contacts'ta ARTIK OLMAMALI,
    - setStatus JSON'daki status ile AYNI olmalı (taze kurulum = düzeltilmiş DB).
    """
    files = sorted(here.glob("corrections_*.json"))
    if not files:
        return ""
    by = {r["slug"]: r for r in records}
    out = ["", "-- " + "=" * 70,
           "-- DOĞRULAMA DÜZELTMELERİ — mevcut veritabanlarına akar (idempotent).",
           "-- Kaynak: corrections_*.json (her satırın gerekçesi yanında)."]
    errors = []
    for f in files:
        out.append(f"-- --- {f.name} ---")
        for c in json.loads(f.read_text(encoding="utf-8")):
            s = c["slug"]
            r = by.get(s)
            if r is None:
                errors.append(f"düzeltme: bilinmeyen slug {s}")
                continue
            for rc in c.get("removeContacts", []):
                if rc["type"] not in CONTACT_TYPES:
                    errors.append(f"düzeltme {s}: geçersiz contact tipi {rc['type']}")
                if any(x.get("type") == rc["type"] and x.get("value") == rc["value"]
                       for x in r.get("contacts", [])):
                    errors.append(f"düzeltme {s}: silinecek değer hâlâ JSON contacts içinde: {rc['value']}")
                out.append(
                    "DELETE FROM location_contacts\n"
                    f"WHERE location_id = (SELECT id FROM locations WHERE slug = {q(s)})\n"
                    f"  AND contact_type = {q(rc['type'])} AND value = {q(rc['value'])}; -- {c.get('reason', '')}"
                )
            st = c.get("setStatus")
            if st:
                if st not in ("published", "draft"):
                    errors.append(f"düzeltme {s}: geçersiz status {st}")
                if r.get("status") != st:
                    errors.append(f"düzeltme {s}: setStatus={st} ama JSON status={r.get('status')}")
                out.append(
                    f"UPDATE locations SET status = {q(st)}\n"
                    f"WHERE slug = {q(s)} AND status <> {q(st)}; -- {c.get('reason', '')}"
                )
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    out.append("")
    return "\n".join(out)


def main():
    here = Path(__file__).resolve().parent
    batches = ["batch1_marinas.json", "batch2_municipal.json", "batch3_piers.json", "batch4_anchorages.json",
               "batch5_expansion.json", "batch6_istanbul.json", "batch7_dogu_akdeniz.json", "batch8_ege_marina.json", "batch9_yunanistan.json",
               "batch10_symi.json", "batch11_yunanistan_koylar.json", "batch12_tr_tamamlama.json", "batch13_tr_tur2.json", "batch14_gr_tur2.json", "batch15_gr_tur3.json", "batch16_gr_tur4.json", "batch17_gr_tur5.json", "batch18_tr_gr_tur6.json", "batch19_tr_tur7.json", "batch20_gr_tur8.json", "batch21_gr_tur9.json", "batch22_gr_tur10.json", "batch23_gr_tur11.json", "batch24_gr_tur12.json", "batch25_gr_yakit1.json", "batch26_gr_tur13.json", "batch27_gr_tur14.json", "batch28_tr_tur15.json", "batch29_ege_tur16.json", "batch30_liman_tur17.json", "batch32_gr_tur19.json", "batch33_iskele_tur20.json", "batch34_ege_akdeniz_tur21.json", "batch35_tr_tur22.json", "batch36_tr_tur23.json", "batch37_gr_tur24.json", "batch38_eksik_tamamlama.json"]
    records, batch_names = [], []
    for b in batches:
        p = here / b
        if not p.exists():
            continue
        data = json.loads(p.read_text(encoding="utf-8"))
        records.extend(data["records"])
        batch_names.append(data["batch"])
    data = {"batch": " + ".join(batch_names), "collectedAt": "2026-07-07/08, 2026-07-11"}
    errors, warnings = validate(records)
    for w in warnings:
        print(f"UYARI: {w}")
    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        sys.exit(1)
    sql = emit(records, data)
    sql += emit_wind(here, records)
    sql += emit_demirleme(here, records)
    sql += emit_yapilandirma(here, records)
    sql += emit_korunak(here, records)
    sql += emit_i18n(here, records)
    # yaklaşma, i18n'den SONRA: birleşik (notlu) metin taban çeviriyi ezmeli.
    sql += emit_yaklasma(here, records)
    sql += emit_corrections(here, records)
    (here.parent / "seed_locations.sql").write_text(sql, encoding="utf-8")
    published = sum(1 for r in records if r["status"] == "published")
    draft = len(records) - published
    def missing(field):
        return sum(1 for r in records if r.get(field) is None)
    print(f"OK: {len(records)} kayıt → seed_locations.sql (published={published}, draft={draft})")
    print(f"Eksikler: berthCount={missing('berthCount')}, maxLoaM={missing('maxLoaM')}, "
          f"maxDraftM={missing('maxDraftM')}, vhf={missing('vhfChannel')}, operator={missing('operator')}")


if __name__ == "__main__":
    main()
