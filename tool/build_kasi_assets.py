#!/usr/bin/env python3
"""raw KASI JSON(assets/data/kasi_*.json)을 앱이 읽기 좋은 압축 포맷으로 변환한다.

입력: assets/data/kasi_lunar.json, kasi_terms.json, kasi_holidays.json, kasi_anniversaries.json
출력: assets/data/lunar_table.json, solarterm_table.json, holiday_table.json, anniversary_table.json
"""
import collections
import json
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "raw_cache")
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "data")
DOCS_HOLIDAYS_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "data", "holidays")


def load(name):
    with open(os.path.join(RAW_DIR, name), "r", encoding="utf-8") as f:
        return json.load(f)


def save(name, data):
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def build_lunar():
    raw = load("kasi_lunar.json")
    out = {}
    for year, items in raw.items():
        for it in items:
            key = f"{it['solYear']}{it['solMonth']}{it['solDay']}"
            out[key] = [
                int(it["lunYear"]),
                int(it["lunMonth"]),
                int(it["lunDay"]),
                1 if it.get("lunLeapmonth") == "윤" else 0,
                it.get("lunIljin", "").split("(")[0],
                it.get("lunSecha", "").split("(")[0],
                it.get("lunWolgeon", "").split("(")[0],
            ]
    save("lunar_table.json", out)
    print(f"lunar_table.json: {len(out)} days")


def build_terms():
    raw = load("kasi_terms.json")
    out = {}
    for year, items in raw.items():
        for it in items:
            date = it["locdate"]
            kst = it.get("kst", "").strip()
            hh = int(kst[:2]) if len(kst) >= 4 else 0
            mm = int(kst[2:4]) if len(kst) >= 4 else 0
            out[date] = {"name": it["dateName"], "hh": hh, "mm": mm}
    save("solarterm_table.json", out)
    print(f"solarterm_table.json: {len(out)} entries")


def build_holidays():
    raw = load("kasi_holidays.json")
    out = {}
    for year, items in raw.items():
        for it in items:
            date = it["locdate"]
            out.setdefault(date, []).append(it["dateName"])
    save("holiday_table.json", out)
    print(f"holiday_table.json: {len(out)} days")
    publish_holidays_to_docs(out)


def publish_holidays_to_docs(holiday_table):
    """C-22/GitHub Pages: 연도별 JSON을 docs/data/holidays/<year>.json 으로 다시 쪼갠다.
    RemoteConfig.holidayJsonUrlForYear가 참조하는 파일이므로 holiday_table.json과 항상 같이 갱신한다.
    """
    by_year = collections.defaultdict(dict)
    for date_key, names in holiday_table.items():
        by_year[date_key[:4]][date_key] = names
    os.makedirs(DOCS_HOLIDAYS_DIR, exist_ok=True)
    for year, entries in by_year.items():
        path = os.path.join(DOCS_HOLIDAYS_DIR, f"{year}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(entries, f, ensure_ascii=False, indent=2)
    print(f"docs/data/holidays: {len(by_year)} year files")


def build_anniversaries():
    raw = load("kasi_anniversaries.json")
    out = {}
    for year, items in raw.items():
        for it in items:
            date = it["locdate"]
            out.setdefault(date, []).append(it["dateName"])
    save("anniversary_table.json", out)
    print(f"anniversary_table.json: {len(out)} days")


if __name__ == "__main__":
    build_lunar()
    build_terms()
    build_holidays()
    build_anniversaries()
