#!/usr/bin/env python3
"""Fetch and normalize the official Microsoft Iraq building-footprints index."""

from __future__ import annotations

import csv
import json
import re
import time
import urllib.request
from pathlib import Path

RELEASE = "2026-08-13"
INDEX_URL = f"https://bfppub.blob.core.windows.net/$web/{RELEASE}/dataset-links.csv"
OUTPUT = Path(__file__).resolve().parents[1] / "Resources" / "iraq_buildings_index.json"


def bytes_from_label(value: str) -> int:
    match = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB)\s*", value, re.IGNORECASE)
    if not match:
        raise ValueError(f"Unrecognized Microsoft size label: {value!r}")
    multiplier = {"B": 1, "KB": 1024, "MB": 1024**2, "GB": 1024**3}[match.group(2).upper()]
    return round(float(match.group(1)) * multiplier)


def download_index() -> str:
    for attempt in range(1, 6):
        try:
            chunks = []
            with urllib.request.urlopen(INDEX_URL, timeout=120) as response:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    chunks.append(chunk)
            return b"".join(chunks).decode("utf-8-sig")
        except Exception:
            if attempt == 5:
                raise
            time.sleep(attempt * 2)
    raise RuntimeError("Could not download the official index")


def main() -> None:
    rows = csv.DictReader(download_index().splitlines())
    tiles = []
    seen = set()
    for row in rows:
        if row.get("Location", "").strip().casefold() != "iraq":
            continue
        quadkey = row["QuadKey"].strip()
        if not re.fullmatch(r"[0-3]{9}", quadkey):
            raise ValueError(f"Unexpected Iraq quadkey: {quadkey!r}")
        if quadkey in seen:
            raise ValueError(f"Duplicate Iraq quadkey: {quadkey}")
        seen.add(quadkey)
        tiles.append({
            "quadKey": quadkey,
            "url": row["Url"].strip(),
            "sizeBytes": bytes_from_label(row["Size"]),
            "uploadDate": row["UploadDate"].strip(),
        })
    tiles.sort(key=lambda tile: tile["quadKey"])
    if len(tiles) != 107:
        raise ValueError(f"Expected 107 Iraq tiles for {RELEASE}; found {len(tiles)}")
    payload = {
        "release": RELEASE,
        "license": "CDLA-Permissive-2.0",
        "totalBytes": sum(tile["sizeBytes"] for tile in tiles),
        "tiles": tiles,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT}: {len(tiles)} tiles, {payload['totalBytes']:,} bytes")


if __name__ == "__main__":
    main()
