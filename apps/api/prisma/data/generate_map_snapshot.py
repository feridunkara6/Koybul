#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gömülü harita anlık görüntüsü üretici (perf, 2026-08).

batch*.json içindeki YAYINLI kayıtlardan, sunucunun cluster ızgarasıyla aynı
formülü (360 / 2^(zoom+2), apps/api cluster.ts) kullanarak zoom-7 balon özeti
üretir ve apps/mobile/assets/map/map_snapshot.json dosyasına yazar. Uygulama
ilk ziyarette (cihaz önbelleği boşken) haritayı bu görüntüyle ANINDA doldurur;
taze veri gelince yerini bırakır.

DÜRÜSTLÜK: balon sayıları gerçek yayınlı kayıt sayılarıdır; konum, üyelerin
ortalamasıdır — uydurma veri yoktur. Veri turlarından sonra yeniden koşun:
    python3 generate_map_snapshot.py
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(
    HERE, "..", "..", "..", "mobile", "assets", "map", "map_snapshot.json"))

# Sunucuyla aynı (cluster.ts): açılış görünümü zoom 7 → hücre 360/2^9 derece.
SNAPSHOT_ZOOM = 7
CELL = 360.0 / (2 ** (SNAPSHOT_ZOOM + 2))


def seeded_batches():
    """Parti listesi generate_locations_seed.py'den okunur — canlıya GİRMEYEN
    partiler (ör. seed listesinde olmayan taslak turlar) anlık görüntüye de
    girmez; iki üretici hep aynı kümeyi kullanır."""
    src = open(os.path.join(HERE, "generate_locations_seed.py"),
               encoding="utf-8").read()
    m = re.search(r"batches = \[(.*?)\]", src, re.S)
    if not m:
        print("HATA: generate_locations_seed.py içinde parti listesi bulunamadı")
        sys.exit(1)
    return re.findall(r'"(batch[^"]+\.json)"', m.group(1))


def main():
    records = []
    for name in seeded_batches():
        path = os.path.join(HERE, name)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            records.extend(json.load(fh)["records"])
    pub = [r for r in records if r.get("status") == "published"]
    if len(pub) < 100:  # emniyet: veri kaynağı bozuksa yarım dosya üretme
        print(f"HATA: yayınlı kayıt beklenmedik kadar az ({len(pub)})")
        sys.exit(1)

    cells = {}
    for r in pub:
        key = (math.floor(r["lon"] / CELL), math.floor(r["lat"] / CELL),
               r.get("countryCode", ""))
        cells.setdefault(key, []).append(r)

    clusters = []
    for (_, _, country), members in sorted(
            cells.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        lons = [m["lon"] for m in members]
        lats = [m["lat"] for m in members]
        clusters.append({
            "position": {
                "lat": round(sum(lats) / len(lats), 5),
                "lon": round(sum(lons) / len(lons), 5),
            },
            "count": len(members),
            # bbox = üyelerin gerçek kapsamı (balona dokununca kamera hedefi).
            "bbox": [round(min(lons), 5), round(min(lats), 5),
                     round(max(lons), 5), round(max(lats), 5)],
            "countryCode": country,
        })

    snapshot = {
        # savedAt: derleme zamanı bilinçli SABİT değil — cihaz önbelleğiyle
        # karışmasın diye alan hiç yazılmaz (çözücü yokluğunu tolere eder).
        "pins": [],  # zoom-7 görünümü balon modudur; pinler ağdan gelir.
        "clusters": clusters,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(snapshot, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    print(f"OK: {len(pub)} yayınlı kayıt → {len(clusters)} balon → {OUT}")


if __name__ == "__main__":
    main()
