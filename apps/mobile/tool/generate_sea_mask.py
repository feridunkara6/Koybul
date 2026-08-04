#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Su/kara bit haritası üretici (deniz rotası motoru, 2026-08).

Kaynak: Natural Earth 10m kara poligonları + küçük adalar — KAMU MALI
(https://www.naturalearthdata.com, GitHub: nvkelso/natural-earth-vector).
Çıktı: apps/mobile/assets/route/sea_mask.bin (elle düzenlenmez).

Bölge: lon 19.4..37.0, lat 34.4..41.7 — İyon (Paksos) + Ege + Marmara +
doğu Akdeniz kıyısı. Çözünürlük 0.005° (~500 m).

EMNİYET PAYI: kıyı çizgileri 1 hücre kalemle de çizilir — yarım-hücrelik
kara parçaları (dil, sığ burun) su sayılamaz. Bedeli: çok dar geçitler
(ör. Kekova iç kanalı, Simi limanı) kapalı görünür; rota motoru bu koylara
"en yakın açık suya kadar" rota üretir. Bu bilinçli, muhafazakâr karardır.

Kullanım:
    python3 tool/generate_sea_mask.py            # ne_*.geojson'ı indirir
Doğrulama: betik sonunda Çanakkale/Marmara bağlantısı denetlenir; KOPUK
çıkarsa dosya YAZILMAZ.
"""
import json
import os
import struct
import sys
import urllib.request
from collections import deque

from PIL import Image, ImageDraw

LON0, LON1, LAT0, LAT1, RES = 19.4, 37.0, 34.4, 41.7, 0.005
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "route", "sea_mask.bin"))
SRC = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
FILES = ("ne_10m_land.geojson", "ne_10m_minor_islands.geojson")


def fetch(name):
    path = os.path.join(HERE, name)
    if not os.path.exists(path):
        print("indiriliyor:", name)
        urllib.request.urlretrieve(SRC + name, path)
    return path


def main():
    w = round((LON1 - LON0) / RES)
    h = round((LAT1 - LAT0) / RES)
    img = Image.new("1", (w, h), 0)
    dr = ImageDraw.Draw(img)

    def px(lon, lat):
        return ((lon - LON0) / RES, (LAT1 - lat) / RES)

    n = 0
    for name in FILES:
        for f in json.load(open(fetch(name), encoding="utf-8"))["features"]:
            g = f["geometry"]
            polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
            for rings in polys:
                xs = [p[0] for p in rings[0]]
                ys = [p[1] for p in rings[0]]
                if max(xs) < LON0 - 0.1 or min(xs) > LON1 + 0.1:
                    continue
                if max(ys) < LAT0 - 0.1 or min(ys) > LAT1 + 0.1:
                    continue
                pts = [px(x, y) for x, y in rings[0]]
                if len(pts) >= 3:
                    dr.polygon(pts, fill=1, outline=1)
                    dr.line(pts + [pts[0]], fill=1, width=1)  # emniyet payı
                for hole in rings[1:]:
                    hp = [px(x, y) for x, y in hole]
                    if len(hp) >= 3:
                        dr.polygon(hp, fill=0)
                n += 1
    print(f"poligon: {n}, ızgara: {w}x{h}")

    data = img.tobytes()
    stride = (w + 7) // 8

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
        "Lakka-Paksos": (20.12, 39.25), "Antalya": (30.8, 36.6),
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
