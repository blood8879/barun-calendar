#!/usr/bin/env python3
"""assets/data/lunar_table.json(일 단위) -> assets/data/lunar_1899_2050.bin (명세 §4-2 포맷).

절기/공휴일/기념일은 KASI 확정 범위가 부분적(2000~2028)이라 명세 §4-3의
"dateConfirmed 전항목 1이어야 빌드 실패" 요구를 정직하게 만족할 수 없다.
그래서 이번 빌드는 음력 테이블만 바이너리로 전환하고, 절기/공휴일/기념일은
JSON 유지 + OPEN_QUESTIONS.md에 사유를 남긴다(허위로 확정 표시하지 않기 위함).
"""
import json
import os
import struct
import zlib
from datetime import date

RAW = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "lunar_table.json")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "lunar_1899_2050.bin")

START_YEAR = 1899
YEAR_COUNT = 152  # 1899..2050


def jdn(y, m, d):
    a = (14 - m) // 12
    y2 = y + 4800 - a
    m2 = m + 12 * a - 3
    return d + (153 * m2 + 2) // 5 + 365 * y2 + y2 // 4 - y2 // 100 + y2 // 400 - 32045


def build():
    with open(RAW, "r", encoding="utf-8") as f:
        raw = json.load(f)

    # key "yyyymmdd" (solar) -> [lunYear, lunMonth, lunDay, isLeap, ...]
    by_lunar_year = {}
    for key, v in raw.items():
        sol_y, sol_m, sol_d = int(key[0:4]), int(key[4:6]), int(key[6:8])
        lun_y, lun_m, lun_d, is_leap = v[0], v[1], v[2], v[3]
        by_lunar_year.setdefault(lun_y, {}).setdefault((lun_m, is_leap), []).append(
            (sol_y, sol_m, sol_d, lun_d)
        )

    body = bytearray()
    missing_years = []
    for i in range(YEAR_COUNT):
        year = START_YEAR + i
        months = by_lunar_year.get(year)
        if not months:
            # KASI 실데이터 범위 밖(원본이 못 채운 해) — 0으로 채우고 기록만 남김.
            missing_years.append(year)
            body += struct.pack("<I", 0)
            continue

        # 월 순서: (월번호, 윤달여부) 오름차순, 각 월의 실제 일수 = 다음 월 시작일 - 이 월 시작일
        month_keys = sorted(months.keys(), key=lambda k: (k[0], k[1]))
        starts = []
        for mk in month_keys:
            days = months[mk]
            first = min(days, key=lambda t: t[3])
            starts.append((mk, jdn(first[0], first[1], first[2])))
        starts.sort(key=lambda t: t[1])

        month_bits = 0
        leap_index = 0
        for idx, ((mnum, is_leap), start_jdn) in enumerate(starts):
            if idx + 1 < len(starts):
                length = starts[idx + 1][1] - start_jdn
            else:
                # 마지막 달: 다음 해 정월 시작이 있으면 그걸로, 없으면 29일 가정
                next_year_months = by_lunar_year.get(year + 1)
                if next_year_months:
                    nm_keys = sorted(next_year_months.keys(), key=lambda k: (k[0], k[1]))
                    nfirst = min(next_year_months[nm_keys[0]], key=lambda t: t[3])
                    length = jdn(nfirst[0], nfirst[1], nfirst[2]) - start_jdn
                else:
                    length = 29
            if length not in (29, 30):
                length = 30 if length > 29 else 29
            if length == 30:
                month_bits |= 1 << idx
            if is_leap:
                leap_index = mnum

        sol_jan1 = jdn(year - 1 if False else year, 1, 1)  # placeholder, overwritten below
        # 설날 = 그 음력연도의 첫 달 시작일. 기준 양력 1/1은 "그 해"(음력연-표기와 동일한 양력연)로 정의.
        first_start_jdn = starts[0][1]
        sol_jan1 = jdn(year, 1, 1)
        newyear_offset = first_start_jdn - sol_jan1

        value = (month_bits & 0x1FFF)
        value |= (leap_index & 0xF) << 13
        offset_clamped = max(0, min(0x3F, newyear_offset))
        value |= (offset_clamped & 0x3F) << 17
        body += struct.pack("<I", value)

    crc = zlib.crc32(bytes(body)) & 0xFFFFFFFF
    header = bytearray(16)
    header[0:4] = b"BLUN"
    header[4] = 1
    header[5] = 0
    struct.pack_into("<H", header, 6, START_YEAR)
    struct.pack_into("<H", header, 8, YEAR_COUNT)
    struct.pack_into("<I", header, 10, crc)

    with open(OUT, "wb") as f:
        f.write(header)
        f.write(body)

    print(f"lunar_1899_2050.bin: {len(header) + len(body)} bytes, missing years: {len(missing_years)}")
    if missing_years:
        print(f"  missing (no KASI data, zero-filled): {missing_years[:10]}{'...' if len(missing_years) > 10 else ''}")
    return missing_years


if __name__ == "__main__":
    build()
