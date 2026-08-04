#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Türk karasuları tercihi ızgarası üretici (kaptan kuralı, 2026-08).

Kaynak: Natural Earth 10m ülke poligonları — KAMU MALI
(GitHub: nvkelso/natural-earth-vector, geojson/ne_10m_admin_0_countries.geojson).
Çıktı: apps/mobile/assets/route/tr_coast_dist.bin (KYBTR2, elle düzenlenmez).

Her ~2 km hücre için: Türk karasına ızgara uzaklığı (nm, bit 0-6, ×2) ve
"Yunan tarafı" bayrağı (Yunan karası daha yakın — bit 7). SINIR ÇİZMEZ:
resmî karasuları iddiası değildir; rota yalnız TERCİH (yumuşak maliyet) yapar.

Kullanım: python3 tool/generate_tr_waters_grid.py  (geojson'ı indirir)
"""
import json
import os
import struct
import urllib.request
from collections import deque

from PIL import Image, ImageDraw

LON0, LON1, LAT0, LAT1, RES = 19.4, 37.0, 34.4, 41.7, 0.005
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "route", "tr_coast_dist.bin"))
SRC = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
       "master/geojson/ne_10m_admin_0_countries.geojson")

def main():
    w = round((LON1 - LON0) / RES); h = round((LAT1 - LAT0) / RES)
    path = os.path.join(HERE, "ne_10m_admin_0_countries.geojson")
    if not os.path.exists(path):
        print("indiriliyor: ülke poligonları (~24 MB)")
        urllib.request.urlretrieve(SRC, path)
    data = json.load(open(path, encoding="utf-8"))

    def rasterize(admin):
        img = Image.new("1", (w, h), 0)
        dr = ImageDraw.Draw(img)
        px = lambda lon, lat: ((lon - LON0) / RES, (LAT1 - lat) / RES)
        f = next(f for f in data["features"] if f["properties"].get("ADMIN") == admin)
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for rings in polys:
            pts = [px(x, y) for x, y in rings[0]]
            if len(pts) >= 3:
                dr.polygon(pts, fill=1, outline=1)
        return img.tobytes()

    def bfs(mask):
        stride = (w + 7) // 8
        dist = [65535] * (w * h); q = deque()
        for cy in range(h):
            base = cy * stride
            for cx in range(w):
                if (mask[base + (cx >> 3)] >> (7 - (cx & 7))) & 1:
                    dist[cy * w + cx] = 0; q.append((cx, cy))
        while q:
            x, y = q.popleft(); dv = dist[y * w + x] + 1
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and dist[ny * w + nx] > dv:
                    dist[ny * w + nx] = dv; q.append((nx, ny))
        return dist

    print("TR..."); d_tr = bfs(rasterize("Turkey"))
    print("GR..."); d_gr = bfs(rasterize("Greece"))

    f = 4; w2, h2 = w // f, h // f
    latnm = 60 * RES
    out = bytearray(w2 * h2)
    for by in range(h2):
        for bx in range(w2):
            mtr = mgr = 65535
            for yy in range(by * f, by * f + f):
                row = yy * w
                for xx in range(bx * f, bx * f + f):
                    if d_tr[row + xx] < mtr: mtr = d_tr[row + xx]
                    if d_gr[row + xx] < mgr: mgr = d_gr[row + xx]
            b = min(127, int(round(mtr * latnm * 2)))
            if mgr < mtr:
                b |= 0x80
            out[by * w2 + bx] = b
    hdr = b"KYBTR2" + struct.pack("<5d2i", LON0, LAT0, LON1, LAT1, RES * f, w2, h2)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as fh:
        fh.write(hdr + bytes(out))
    print("yazıldı:", OUT, os.path.getsize(OUT), "bayt")

if __name__ == "__main__":
    main()
