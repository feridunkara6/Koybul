#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Su/kara bit haritası üretici v2 (deniz rotası motoru, 2026-08).

KAYNAK (v2): GSHHG tam çözünürlük kıyı poligonları — GSHHS_f_L1.shp
(Global Self-consistent, Hierarchical, High-resolution Geography; LGPL,
WVS + WDBII kamu kaynaklarından türetilmiştir; dağıtım: GitHub
pelson/gshhs-unpacked). v1'in kaynağı Natural Earth 10m idi; KÜÇÜK EGE
ADACIKLARINI içermediği için rota nadiren adacık üstünden geçebiliyordu
(kullanıcı bildirimi 2026-08). GSHHG-f bu adacıkları içerir.

Çıktı: apps/mobile/assets/route/sea_mask.bin (elle düzenlenmez; biçim v1
ile BİREBİR aynı: 'KYBSU1' + 5×double LE + 2×int32 LE + bit-paketli maske,
bit 1 = KARA, üst satır = kuzey, satır hizası (w+7)//8, MSB soldaki hücre).

Bölge: lon 19.4..37.0, lat 34.4..41.7 — İyon + Ege + Marmara + doğu Akdeniz.
Çözünürlük 0.005° (~500 m). EMNİYET PAYI: kıyı kenarları 1 hücre kalemle de
işlenir — yarım-hücrelik kara parçaları su sayılamaz. Bedeli: çok dar
geçitler (ör. Kekova iç kanalı) kapalı görünür; bu bilinçli karardır.

Kullanım:
    python3 tool/generate_sea_mask.py     # GSHHS_f_L1.shp yoksa indirir
Doğrulama: kritik su bağlantıları (Çanakkale/Marmara vb.) denetlenir;
KOPUK çıkarsa dosya YAZILMAZ.
"""
import math
import os
import struct
import sys
import urllib.request
from collections import deque

LON0, LON1, LAT0, LAT1, RES = 19.4, 37.0, 34.4, 41.7, 0.005
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "route", "sea_mask.bin"))
SHP = os.path.join(HERE, "GSHHS_f_L1.shp")
SRC = ("https://media.githubusercontent.com/media/pelson/gshhs-unpacked/"
       "master/GSHHS_shp/f/GSHHS_f_L1.shp")
MARGIN = 0.2  # bbox filtre payı (derece)

# BOĞAZ MUAFİYETİ: tam çözünürlükte 1 hücrelik emniyet kalemi Çanakkale'nin
# en dar yerini (≈1.2 km ≈ 2 hücre) mühürlüyor. Bu kutularda kalem atlanır,
# yalnız dolgu çalışır — GSHHG-f kıyısı burada zaten hassastır.
STROKE_SKIP = (
    (26.10, 39.90, 26.80, 40.50),  # Çanakkale Boğazı
    (28.90, 40.90, 29.30, 41.40),  # İstanbul Boğazı
)


def fetch():
    if not os.path.exists(SHP):
        print("indiriliyor: GSHHS_f_L1.shp (~161 MB)")
        urllib.request.urlretrieve(SRC, SHP)
    return SHP


def main():
    w = round((LON1 - LON0) / RES)
    h = round((LAT1 - LAT0) / RES)
    stride = (w + 7) // 8
    land = bytearray(stride * h)

    def set_cell(cx, cy):
        if 0 <= cx < w and 0 <= cy < h:
            land[cy * stride + (cx >> 3)] |= 0x80 >> (cx & 7)

    def col_of(lon):  # hücre merkezi esaslı sütun
        return (lon - LON0) / RES - 0.5

    # Satır merkez enlemleri (üst satır = kuzey).
    row_lat = [LAT1 - (r + 0.5) * RES for r in range(h)]
    crossings = [[] for _ in range(h)]  # çift-tek doldurma için kenar kesişimleri

    def add_edge(x0, y0, x1, y1):
        # 1) Doldurma kesişimleri: kenar hangi satır merkezlerini kesiyor?
        if y0 != y1:
            ylo, yhi = (y0, y1) if y0 < y1 else (y1, y0)
            # PARİTE DERSİ: GSHHG köşeleri sık sık TAM satır merkezine denk
            # gelir; kırpma aralığı float gürültüsüyle o satırı dışlarsa
            # kesişim düşer ve satır paritesi bozulur (deniz karaya döner).
            # Aralık 1'er satır GENİŞ tutulur; gerçek karar alttaki koşulda.
            r0 = max(0, int(math.ceil((LAT1 - yhi) / RES - 0.5)) - 1)
            r1 = min(h - 1, int(math.floor((LAT1 - ylo) / RES - 0.5)) + 1)
            for r in range(r0, r1 + 1):
                yc = row_lat[r]
                if (y0 > yc) != (y1 > yc):
                    t = (yc - y0) / (y1 - y0)
                    crossings[r].append(x0 + (x1 - x0) * t)
        # 2) Emniyet kalemi: bölgeye değen kenarlar 1 hücre çizilir (süpürme).
        if (max(x0, x1) < LON0 - MARGIN or min(x0, x1) > LON1 + MARGIN or
                max(y0, y1) < LAT0 - MARGIN or min(y0, y1) > LAT1 + MARGIN):
            return
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        for (sx0, sy0, sx1, sy1) in STROKE_SKIP:
            if sx0 <= mx <= sx1 and sy0 <= my <= sy1:
                return  # boğaz muafiyeti — yalnız dolgu
        cx0, cy0 = (x0 - LON0) / RES, (LAT1 - y0) / RES
        cx1, cy1 = (x1 - LON0) / RES, (LAT1 - y1) / RES
        steps = int(max(abs(cx1 - cx0), abs(cy1 - cy0)) * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            set_cell(int(cx0 + (cx1 - cx0) * t), int(cy0 + (cy1 - cy0) * t))

    # --- Shapefile akış çözümü (tip 5 = Polygon; GSHHS L1'de delik yok) ---
    n_poly = 0
    with open(fetch(), "rb") as fh:
        fh.seek(0, 2)
        size = fh.tell()
        fh.seek(100)  # dosya başlığı
        while fh.tell() < size:
            rec = fh.read(8)
            if len(rec) < 8:
                break
            (_, clen) = struct.unpack(">2i", rec)  # içerik 16-bit kelime
            content = fh.read(clen * 2)
            shape_type = struct.unpack_from("<i", content, 0)[0]
            if shape_type != 5:
                continue
            xmin, ymin, xmax, ymax = struct.unpack_from("<4d", content, 4)
            if (xmax < LON0 - MARGIN or xmin > LON1 + MARGIN or
                    ymax < LAT0 - MARGIN or ymin > LAT1 + MARGIN):
                continue
            n_parts, n_pts = struct.unpack_from("<2i", content, 36)
            parts = list(struct.unpack_from("<%di" % n_parts, content, 44))
            pts_off = 44 + 4 * n_parts
            parts.append(n_pts)
            for pi in range(n_parts):
                a, b = parts[pi], parts[pi + 1]
                if b - a < 3:
                    continue
                px_prev = py_prev = None
                for k in range(a, b):
                    x, y = struct.unpack_from("<2d", content, pts_off + 16 * k)
                    if px_prev is not None:
                        add_edge(px_prev, py_prev, x, y)
                    px_prev, py_prev = x, y
            n_poly += 1
    print(f"poligon: {n_poly}, ızgara: {w}x{h}")

    # Çift-tek doldurma: satır başına sıralı kesişim çiftleri → kara aralıkları.
    for r in range(h):
        xs = sorted(crossings[r])
        for i in range(0, len(xs) - 1, 2):
            c0 = max(0, int(math.ceil(col_of(xs[i]))))
            c1 = min(w - 1, int(math.floor(col_of(xs[i + 1]))))
            base = r * stride
            for c in range(c0, c1 + 1):
                land[base + (c >> 3)] |= 0x80 >> (c & 7)

    data = bytes(land)

    def is_land(cx, cy):
        return (data[cy * stride + (cx >> 3)] >> (7 - (cx & 7))) & 1

    # Bağlantı doğrulaması: Ege açık denizinden BFS — kritik noktalar bağlı mı?
    def cell(lon, lat):
        return (int((lon - LON0) / RES), int((LAT1 - lat) / RES))

    start = cell(25.0, 38.0)
    seen = bytearray(w * h)
    q = deque([start])
    seen[start[1] * w + start[0]] = 1
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and not is_land(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))
    kritik = {
        "Marmara": (27.75, 40.55), "İstanbul önü": (28.9, 40.9),
        "Gökova": (27.9, 36.98), "Fethiye körfezi": (29.03, 36.66),
        # Lakka: tam çözünürlükte burun 1 hücre büyüdü; denetim noktası koy
        # AĞZINDAKİ suya alındı (20.12,39.25 artık kıyı hücresi).
        "Lakka-Paksos yaklaşımı": (20.11, 39.26), "Antalya": (30.8, 36.6),
    }
    for ad, (lon, lat) in kritik.items():
        cx, cy = cell(lon, lat)
        if is_land(cx, cy) or not seen[cy * w + cx]:
            print(f"HATA: {ad} bağlantısı KOPUK — dosya yazılmadı.")
            sys.exit(1)
        print(f"bağlantı OK: {ad}")

    hdr = b"KYBSU1" + struct.pack("<5d2i", LON0, LAT0, LON1, LAT1, RES, w, h)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as fh:
        fh.write(hdr + data)
    print("yazıldı:", OUT, os.path.getsize(OUT), "bayt")


if __name__ == "__main__":
    main()
