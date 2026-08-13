#!/usr/bin/env python3
"""KASI 공공데이터포털에서 음양력/24절기/공휴일 원자료를 조회해 assets/data/*.json 으로 굽는다.

사용법:
  KASI_SERVICE_KEY=... python3 tool/fetch_kasi_data.py --from 2015 --to 2035

주의:
- serviceKey는 이미 URL-decode된 원문 키를 넣으면 이 스크립트가 자체적으로 인코딩해 요청한다.
- 무료 트래픽 한도(1일 1,000회)를 고려해 연도 범위를 필요한 만큼만 지정할 것.
  범위를 넓히려면 여러 날에 나눠 --from/--to를 바꿔가며 재실행하면 기존 파일에 병합된다.
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

BASE = "http://apis.data.go.kr/B090041/openapi/service"
OUT_DIR = os.path.join(os.path.dirname(__file__), "raw_cache")


def call(service, op, params, key):
    q = dict(params)
    q["serviceKey"] = key
    q["_type"] = "xml"
    url = f"{BASE}/{service}/{op}?{urllib.parse.urlencode(q)}"
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=15) as resp:
                data = resp.read()
            root = ET.fromstring(data)
            code = root.findtext("header/resultCode")
            if code != "00":
                msg = root.findtext("header/resultMsg")
                raise RuntimeError(f"KASI API error {code}: {msg} ({url})")
            return root.findall("body/items/item")
        except Exception as e:
            if attempt == 2:
                raise
            time.sleep(1.5 * (attempt + 1))
    return []


def item_to_dict(item):
    return {child.tag: (child.text or "").strip() for child in item}


def fetch_lunar(year, key):
    result = []
    for month in range(1, 13):
        items = call(
            "LrsrCldInfoService",
            "getLunCalInfo",
            {"solYear": year, "solMonth": f"{month:02d}", "numOfRows": 31},
            key,
        )
        result.extend(item_to_dict(i) for i in items)
    return result


def fetch_terms(year, key):
    items = call(
        "SpcdeInfoService",
        "get24DivisionsInfo",
        {"solYear": year, "numOfRows": 30},
        key,
    )
    return [item_to_dict(i) for i in items]


def fetch_holidays(year, key):
    items = call(
        "SpcdeInfoService",
        "getRestDeInfo",
        {"solYear": year, "numOfRows": 50},
        key,
    )
    return [item_to_dict(i) for i in items]


def fetch_anniversaries(year, key):
    items = call(
        "SpcdeInfoService",
        "getAnniversaryInfo",
        {"solYear": year, "numOfRows": 50},
        key,
    )
    return [item_to_dict(i) for i in items]


def load_existing(path):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="year_from", type=int, required=True)
    ap.add_argument("--to", dest="year_to", type=int, required=True)
    ap.add_argument("--key", dest="key", default=os.environ.get("KASI_SERVICE_KEY"))
    args = ap.parse_args()

    if not args.key:
        print("KASI_SERVICE_KEY env or --key required", file=sys.stderr)
        sys.exit(1)

    os.makedirs(OUT_DIR, exist_ok=True)
    lunar_path = os.path.join(OUT_DIR, "kasi_lunar.json")
    terms_path = os.path.join(OUT_DIR, "kasi_terms.json")
    holidays_path = os.path.join(OUT_DIR, "kasi_holidays.json")
    anniv_path = os.path.join(OUT_DIR, "kasi_anniversaries.json")

    lunar = load_existing(lunar_path)
    terms = load_existing(terms_path)
    holidays = load_existing(holidays_path)
    anniv = load_existing(anniv_path)

    for year in range(args.year_from, args.year_to + 1):
        y = str(year)
        print(f"[{year}] 음양력...", flush=True)
        lunar[y] = fetch_lunar(year, args.key)
        print(f"[{year}] 24절기...", flush=True)
        terms[y] = fetch_terms(year, args.key)
        print(f"[{year}] 공휴일...", flush=True)
        holidays[y] = fetch_holidays(year, args.key)
        print(f"[{year}] 잡절/기념일...", flush=True)
        anniv[y] = fetch_anniversaries(year, args.key)

        with open(lunar_path, "w", encoding="utf-8") as f:
            json.dump(lunar, f, ensure_ascii=False)
        with open(terms_path, "w", encoding="utf-8") as f:
            json.dump(terms, f, ensure_ascii=False)
        with open(holidays_path, "w", encoding="utf-8") as f:
            json.dump(holidays, f, ensure_ascii=False)
        with open(anniv_path, "w", encoding="utf-8") as f:
            json.dump(anniv, f, ensure_ascii=False)

    print("done. wrote:", lunar_path, terms_path, holidays_path, anniv_path)


if __name__ == "__main__":
    main()
