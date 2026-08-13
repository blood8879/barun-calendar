# 진행 로그

## Phase 1 — 프로젝트 셋업 + 규칙 기반 달력 코어 (완료)
- `flutter create` 로 Android 타겟 Flutter 프로젝트 생성 (`com.baruncal.barun_calendar`)
- 명세 §1-2 고정 디렉터리 구조 생성 (`lib/domain`, `lib/data`, `lib/ui`, `tool`, `assets/data`, `test/calendar`)
- `lib/domain/calendar/jdn.dart`: JDN ↔ 그레고리력 변환, 요일 계산 (K1 — 정수 JDN만 사용)
- `lib/domain/calendar/ganji.dart`: 일진(C-12) · 세차(C-13) · 월건(C-14) 공식
- `lib/domain/calendar/japjeol.dart`: 삼복(C-15, 월복 포함) · 한식(C-16) 공식
- `test/calendar/ganji_japjeol_test.dart`: §13-A 고정 테스트 벡터 전량 구현
  - 일진: 2000-01-01=무오, 2023-06-21=경술
  - 삼복: 2015/2020/2023(월복 케이스)/2024/2025 — 5개 세트 전부 일치
  - 한식: 2022 동지→2023 한식 4/6
  - 세차: 2024=갑진, 2040=경신
  - 월건: 2023-10-08(한로) 이후=임술월

**QA**: `flutter test test/calendar/ganji_japjeol_test.dart` → **13/13 통과**.

## Phase 2 — KASI 미확보 상태에서 진행 가능한 부분 (완료)
사용자가 "KASI 공식 API키로 하자"고 확정했으나 실제 서비스키는 아직 미전달. 서비스키가
와야만 정확한 값을 낼 수 있는 부분(음력/24절기/공휴일 실데이터)은 손대지 않고, 그 외
데이터소스와 무관한 나머지 구조를 구현했다.

- `domain/calendar/day_info.dart`: `DayInfo`, `LunarDate`, `SolarTerm`, `HolidayInfo` 값 객체 +
  `LunarCalendarDataSource`/`SolarTermDataSource`/`HolidayDataSource` 추상 인터페이스 +
  이를 조합하는 `DayInfoProvider`. KASI 실연동은 이 인터페이스의 구현체 하나만 갈아끼우면 된다.
- `data/fake/fake_calendar_data_sources.dart`: 개발/테스트 전용 **Fake** 구현체 3종. 클래스/파일명에
  Fake를 명시하고 최상단에 "실제 서비스 빌드 금지" 경고 주석을 달아 오인 가능성을 차단.
- `domain/event/event.dart` + `data/event/event_repository.dart`: 일정 모델과 CRUD 저장소
  (`SharedPrefsEventRepository`, JSON 직렬화). 백업/복원용 `replaceAll` 포함.
- `ui/home/home_screen.dart`: 월 캘린더 그리드(일진 표시, 공휴일/토요일 색상, 오늘 표시, 이벤트 dot),
  월 이동.
- `ui/date_detail/date_detail_sheet.dart`: 날짜상세 바텀시트(디자인 목업 S2 대응) — 일진/음력(자리표시)/
  절기/공휴일 표시, 일정 목록·추가·삭제.
- `lib/main.dart`: 앱 진입점을 카운터 데모에서 실제 홈 화면으로 교체.

**QA**: `flutter analyze` → 기존 2건(무해한 dangling doc comment info)만, 오류 0.
`flutter test` → **15/15 통과** (기존 13건 + 신규 위젯 테스트 2건: 홈 화면 렌더링, 날짜 탭→일정 추가 흐름).

## Phase 3 — KASI와 무관한 나머지 화면 (완료)
KASI 서비스키는 여전히 미전달 상태라 음력/절기 실데이터는 그대로 Fake 데이터소스를 쓴다.
그와 무관한 화면들을 실제로 구현했다.

- `data/settings/settings_repository.dart`: `AppSettings`(다크모드/글자배율/표시항목 4종 토글) +
  `SharedPrefsSettingsRepository`.
- `data/config/remote_config.dart`: 정적 공휴일 JSON 원격 URL 설정값 분리(B-4 결정 전까지 GitHub Raw
  형식의 플레이스홀더, OPEN_QUESTIONS #2 확정되면 이 상수만 교체).
- `ui/settings/settings_screen.dart`: 디자인 목업 S8 대응 — 다크모드, 글자 크기 슬라이더(85~150%),
  표시 항목 4종 토글, 백업/복원 진입점.
- `ui/search/search_screen.dart`: 디자인 목업 S7 대응 — 제목/메모 텍스트 검색(F18 무료 검색).
- `ui/backup/backup_restore_screen.dart`: 디자인 목업 S9 대응 — 일정 JSON 클립보드 내보내기/붙여넣기
  복원. 형식이 다르면(X1-백업불일치 케이스) 조용히 무시하지 않고 명시적 오류 문구를 보여준다.
  실기기 파일 공유 시트/파일선택기(share_plus/file_picker) 연동은 아직 미착수(스코프 노트 참고).
- `lib/main.dart`: 설정을 앱 부팅 시 로드해 `ThemeMode`·글자 배율(`TextScaler`)에 실제로 반영.
- 홈 화면 앱바에 검색/설정 진입 아이콘 추가.

**QA**: `flutter analyze` → 오류 0(무해한 info 2건만, 기존과 동일).
`flutter test` → **19/19 통과** (기존 15건 + 신규 4건: 다크모드 토글 저장, 검색 필터링, 백업
내보내기, 백업 복원 실패 시 오류 문구).

## Phase 4 이후 — 아직 미착수
아래는 KASI 키와 무관하게 진행 가능하지만 이번 라운드 스코프 밖으로 남겨둔 항목이다(시간 제약).
다음 라운드에서 이어서 진행 가능:
- **가져오기(F19)**: 다른 캘린더 앱(ICS 등) 가져오기 UI/파서 — 디자인 목업 S10.
- **위젯(F5, 3종)**: 홈 화면 위젯은 Android 네이티브(App Widget Provider) 연동이 필요해 Flutter
  쪽 데이터 계약만으로는 부족함 — 별도 네이티브 작업 라운드 필요.
- **다단 알림(F4)**: `flutter_local_notifications` 연동 + 권한 요청 플로우 + 반복 일정(음력 기준,
  F3) 알림 스케줄링. 반복 일정 자체(F3)도 아직 도메인 모델에 없음(현재 `CalendarEvent`는 단발성).
- **광고(F12, C-50)**: `google_mobile_ads` 배너 1지면 + UMP 동의 흐름. AndroidManifest에 AdMob
  App ID가 필요하며 테스트 ID로도 실제 배포/디바이스 검증이 필요해 이번 라운드에서는 보류.
- **평생권 IAP(F20, C-48/C-49)**: `in_app_purchase` `barun_lifetime_v1` 비소모성 구매 + 페이월
  사전 고지 문구 + 생애 2회 팝업 제한 로직 — Play Console 상품 등록이 선행되어야 실제 검증 가능.
- **근거 화면(F2, S3)**: 일진/절기 산출 근거를 보여주는 화면 — KASI 실데이터가 있어야 의미가 있어
  보류.
- **기일/생신(F8, S5)**: 음력 기준 반복 기념일 — F3(반복 일정)에 종속.
- **변환기(F14, S6)**: 음↔양 변환기 — KASI 실데이터 필요.
- **가져오기(F19)/페이월(S11)/큰글씨 3단계 명세치 검증/다크 스크린샷 비교 QA**는 화면 스펙 대조까지는
  못했음.

## Phase 4 — KASI와 무관한 나머지 기능 (완료)
KASI 서비스키는 여전히 미전달 상태. 그와 무관한 나머지 기능을 실제로 구현했다.

- `domain/event/event.dart`: 반복 규칙(`RecurrenceType.none/yearly/monthly`) 추가,
  `occurrencesInYear`로 발생일 전개(존재하지 않는 날짜는 안전하게 건너뜀), 다단 알림
  (`reminderMinutesBefore`)으로 기존 `notify` bool 대체(하위호환 fromJson 유지).
- `data/notification/notification_service.dart`: `flutter_local_notifications` 실연동.
  이벤트 저장/삭제 시 향후 2년치 발생분에 대해 알림을 재예약/취소. 미초기화 상태(테스트 등)에서는
  안전하게 no-op.
- `ui/date_detail/date_detail_sheet.dart`: 반복 선택 드롭다운 + 알림 시각 다중 선택 칩,
  기존 일정 탭 시 반복/알림 편집 다이얼로그.
- `ui/home/home_screen.dart`: `_eventsOn`이 반복 발생일까지 포함하도록 수정, 알림 재예약/취소 연결.
- `data/import/ics_parser.dart` + `ui/import/import_screen.dart`: 디자인 목업 S10 대응, ICS
  텍스트 붙여넣기로 SUMMARY/DTSTART 파싱해 일정 가져오기(반복규칙/시간대는 미지원, 단발 일정만).
- `data/purchase/purchase_service.dart` + `ui/paywall/paywall_screen.dart`: 디자인 목업 S11
  대응. `in_app_purchase`로 `barun_lifetime_v1` 비소모성 구매/복원 흐름, 구매 여부를
  SharedPreferences에 저장.
- `ui/ads/ad_banner.dart`: `google_mobile_ads` 공식 테스트 배너 유닛 ID로 하단 배너,
  평생권 보유 시 렌더링하지 않음. 홈 화면 하단에 배치.
- Android 네이티브: `AndroidManifest.xml`에 알림/정확한 알람/부팅수신 권한, AdMob 테스트
  앱 ID meta-data, 위젯 리시버 등록 추가. `widget/MonthlyCalendarWidgetProvider.kt` +
  `res/xml/monthly_calendar_widget_info.xml` + `res/layout/widget_monthly_calendar.xml`로
  홈 화면 위젯(F5) 3종 중 "오늘 날짜 요약" 1종의 골격 구현(오늘 날짜만 표시 — 일진/음력 등 실데이터
  연동은 KASI 확보 후 Flutter→네이티브 데이터 계약 추가 필요). 나머지 2종 위젯은 동일 패턴으로
  추가 가능하나 이번 라운드에서는 미착수.
- `android/app/build.gradle.kts`: `flutter_local_notifications`용 core library desugaring 활성화.

**QA**: `flutter analyze` → 오류 0(기존과 동일한 무해한 info 2건만).
`flutter test` → **25/25 통과** (기존 19건 + 반복/알림 로직 4건 + ICS 파서 2건).
`flutter build apk --debug` → **빌드 성공** (신규 네이티브 코드·매니페스트·의존성 포함해 실제
Android 빌드 검증 완료).

## Phase 5 이후 — 여전히 미착수 (KASI 실데이터 필요)
- 위젯 3종 중 나머지 2종(음력/일진 요약, 다가오는 기념일) — 오늘 위젯과 같은 패턴으로 추가하되
  실제 음력·절기 값이 있어야 의미가 있음.
- 근거 화면(F2/S3), 기일/생신(F8/S5), 변환기(F14/S6).
- 음력 기준 반복(현재 `RecurrenceType`은 양력 기준만 지원 — 음력 반복은 KASI 데이터로 매년 대응
  음력→양력 변환이 필요).
- 실기기 파일 선택기(file_picker)/공유 시트(share_plus) 연동 — 지금은 백업/가져오기 모두 텍스트
  붙여넣기 방식.

## Phase 5 — KASI 실데이터 연동 (완료, 범위 제한)
사용자가 전달한 KASI 서비스키(음양력정보서비스/특일정보 공통)로 실제 연동을 완료했다.

- `curl`로 `LrsrCldInfoService.getLunCalInfo`, `SpcdeInfoService.get24DivisionsInfo`,
  `SpcdeInfoService.getRestDeInfo`, `SpcdeInfoService.getAnniversaryInfo` 4개 오퍼레이션 실호출
  검증 (resultCode 00 정상 응답 확인).
- `tool/fetch_kasi_data.py`: 서비스키로 2000~2040년(41개년) 음양력(월별 1회 호출)·24절기·
  공휴일·잡절(기념일)을 조회해 `tool/raw_cache/kasi_*.json`에 저장(연도별 증분 병합 가능).
- `tool/build_kasi_assets.py`: raw JSON → 앱용 압축 테이블(`assets/data/lunar_table.json`
  14,976일, `solarterm_table.json` 696건, `holiday_table.json` 425일, `anniversary_table.json`
  1,051일)로 변환.
- `lib/data/kasi/kasi_calendar_data_sources.dart`: `KasiLunarCalendarDataSource`/
  `KasiSolarTermDataSource`/`KasiHolidayDataSource` — 앱 시작 시 `KasiCalendarTables.load()`로
  에셋을 1회 로드해 메모리 맵으로 조회(런타임 API 호출 없음, C-22 준수). 음↔양 왕복 변환용
  역인덱스 포함. 근거 화면(F2)용 `ganjiOn()` 원문(일진/세차/월건 KASI 표기) 헬퍼도 포함.
- `main.dart`: `Future.wait([설정 로드, KasiCalendarTables.load()])` 후 `DayInfoProvider`를
  KASI 구현체로 구성해 `HomeScreen`에 주입(Fake는 테스트 전용으로만 남김).
- `test/calendar/kasi_data_source_test.dart`: 실제 KASI 응답값 기준 회귀 테스트 4건 —
  2024-01-01 음력 계묘년 11월 20일(평달), 왕복 변환 항등, 2024 하지 6/21, 2024 설날 연휴.
- 서비스키는 코드에 하드코딩하지 않고 `tool/fetch_kasi_data.py` 실행 시 `--key`/
  `KASI_SERVICE_KEY` 환경변수로만 전달(빌드 도구 전용, 앱 런타임에는 없음). `.gitignore`에
  `.env`, `*.key`, `secrets.json`, `/tool/raw_cache/` 추가.

**QA**: `flutter analyze` → 오류 0. `flutter test` → **29/29 통과**(신규 KASI 검증 4건 포함).
`flutter build apk --debug` → **빌드 성공**(실제 KASI 데이터 에셋 포함).

**명세 대비 남은 차이**(OPEN_QUESTIONS.md #1 상세 참고): 연도 범위 2000~2040(요구는
1899~2050), 저장 포맷을 비트팩 바이너리 대신 JSON으로 대체, §13 L1/L4 대규모 전수검증 미실시.

## Phase 6 — 근거 화면(F2)·변환기(F14) 구현 (완료, 부분 스코프)
KASI 실데이터가 있어야 의미 있던 화면 중 2개를 구현했다.

- `ui/basis/basis_screen.dart`: 디자인 목업 S3 대응. 날짜상세시트의 "근거 보기"에서 진입,
  `KasiLunarCalendarDataSource.ganjiOn()`으로 KASI 공표 일진/세차/월건 원문과 음력/절기/공휴일을
  그대로 표시. 범위 밖 날짜는 조용한 폴백 없이 안내 문구를 보여줌(명세 K5).
- `ui/converter/converter_screen.dart`: 디자인 목업 S6 대응. 홈 화면 앱바에 진입 아이콘 추가.
  양력→음력/음력→양력 양방향 변환, 윤달 지원. 범위 밖·존재하지 않는 음력일은 명시적 안내.
- `HomeScreen`/`DateDetailSheet`가 `LunarCalendarDataSource` 인터페이스를 받아 두 화면에
  전달하도록 배선(구체 타입 `Kasi...`에 묶이지 않아 Fake로도 테스트 가능하게 유지).
- `main.dart`가 부팅 시 만든 `KasiLunarCalendarDataSource`를 `HomeScreen.lunarSource`로 전달.

**QA**: `flutter analyze` → 오류 0(기존과 동일한 무해한 info 2건만).
`flutter test` → **29/29 통과**(기존 테스트 그대로 — 신규 화면 자체의 위젯 테스트는 아직 없음,
다음 라운드에서 보완 필요).
`flutter build apk --debug` → **빌드 성공**.

## Phase 6 이후 — 여전히 미착수
- 연도 범위 확장(2000~2040 → 1899~2050), 비트팩 바이너리 포맷 전환, §13 L1/L4 전수검증
  (OPEN_QUESTIONS.md #1 참고 — 이번 라운드에서 시간 제약으로 시도하지 않음).
- 기일/생신(F8/S5) — 음력 기준 반복 기념일. F3(반복 일정)이 현재 양력 기준만 지원해서 확장 필요.
- 홈 화면 위젯 3종 중 나머지 2종(음력/일진 요약, 다가오는 기념일) — "오늘 날짜" 1종과 같은
  Android AppWidgetProvider 패턴으로 추가 가능.
- 근거 화면/변환기 자체의 위젯 테스트(flutter_test) 추가.

## Phase 7 — 음양력 연도 범위 전체 확장 (완료), 나머지는 스코프 초과
- `tool/fetch_kasi_data.py`로 1899~1979, 1980~2050 두 배치를 추가 실행해 음양력 데이터를
  명세 요구 범위(1899~2050, 152개년, 55,517일)로 완전히 채웠다. 트래픽 한도 초과 없이 완료.
- 그 과정에서 **KASI SpcdeInfoService(24절기/공휴일/잡절) 자체가 2000~2028년(공휴일·잡절은
  2004~2028년)만 정상 데이터를 반환**하는 API 자체 제약을 확인함(빈 목록 응답, 오류 아님).
  코드 버그가 아니라 KASI가 공개한 데이터 범위 문제 — OPEN_QUESTIONS.md #1에 상세 기록.
- `tool/build_kasi_assets.py` 재실행 → `lunar_table.json` 55,517일(전체 범위),
  `solarterm_table.json`/`holiday_table.json`/`anniversary_table.json`은 여전히
  2000~2028년대 범위(각 696/425/1,051건, 이전과 동일 — API가 더 주지 않으므로 늘어나지 않음).
- QA: `flutter analyze` 오류 0, `flutter test` **29/29 통과**.

## Phase 7 이후 — 여전히 미착수 (다음 라운드로 이월)
- 비트팩 바이너리 포맷 전환, §13 L1/L4 전수검증(24절기 데이터 자체 범위 제약으로 부분적으로만
  가능), 기일/생신(F8/S5), 홈 화면 위젯 2종(음력/일진 요약·다가오는 기념일), 신규 화면
  (근거/변환기)의 위젯 테스트.

## Phase 8 — 24절기 KASI 범위 밖(1899~1999, 2029~2050) 천문 계산 보완 (부분 완료)
- `lib/domain/calendar/solar_term_calculator.dart` 신규: Meeus 저정밀 태양 겉보기 황경 공식
  + 이분 탐색으로 24절기 시각을 결정론적으로 계산하는 `SolarTermCalculator` 구현.
- `ComputedFallbackSolarTermDataSource` 추가: KASI 실측(2000~2028) 우선 사용, 범위 밖 연도만
  계산값으로 보완. `lastLookupWasComputed` 플래그로 KASI 실측값과 명확히 구분 가능
  (아직 UI 표기는 미연동 — 아래 남은 작업 참고).
- `lib/main.dart`에서 `KasiSolarTermDataSource`를 `ComputedFallbackSolarTermDataSource`로
  교체해 실제 앱에 연동.
- 교차검증 테스트(`test/calendar/solar_term_calculator_test.dart`) 추가: KASI 실측
  2000/2005/2012/2020/2024/2028년 표본(120건 이상)과 계산값 날짜 비교, 불일치율 5% 미만
  통과 확인 완료.
- 공휴일/잡절(2004~2028년 범위)은 계획대로 **채우지 않음** — 법정 공휴일은 예측이 아니라
  국회/정부가 정하는 사실의 영역이라 임의 계산이 부적절하다고 판단, OPEN_QUESTIONS.md #1에
  "미확정, 추후 KASI 갱신 시 반영" 상태로 명시.
- QA: `flutter analyze` 오류 0(기존 info 2건만), `flutter test` **30/30 통과**.

### 이번 라운드에서 스코프 초과로 미착수 (다음 라운드로 이월)
- 비트팩 바이너리(.bin+CRC32) 포맷 전환
- §13 L1/L4 전수검증(계산 보완 구간 포함한 전체 자동화 테스트)
- 기일/생신 화면(F8/S5)
- 홈 화면 위젯 2종(음력/일진 요약, 다가오는 기념일)
- 근거/변환기 화면 자체 위젯 테스트
- UI에서 "계산값(비공식)" 배지 등 KASI 실측과 계산 보완값을 시각적으로 구분 표시하는 작업
  (데이터 레이어는 구분 가능하나 화면 연동은 아직 안 함)

## Phase 9 — 계산값 배지 UI 연동 + 기일/생신 화면(F8/S5) + 위젯 테스트 (완료)
- `SolarTerm`에 `isComputedFallback` 필드 추가(도메인 레이어에서 직접 구분 가능하도록).
  `SolarTermCalculator.termsInYear()`가 만드는 값은 항상 `true`로 표시.
- `BasisScreen`(S3)·`DateDetailSheet`(S2)에서 `isComputedFallback`이면 "(계산값·비공식)"
  라벨 + 근거 화면에는 "KASI 특일 정보 API 제공 범위(2000~2028) 밖이라 자체 천문 계산으로
  보완했다"는 안내 문구를 추가로 표시.
- `lib/ui/anniversary/anniversary_screen.dart` 신규: 기일/생신(F8/S5) 화면. birthday/memorial
  일정을 모아 다가오는 발생일(D-day) 순으로 정렬. `CalendarEvent.lunarOccurrenceInYear()`
  (신규 메서드, `lib/domain/event/event.dart`)로 `isLunar` 일정의 원래 음력 월/일을 구해
  대상 연도의 실제 양력 발생일을 KASI 데이터로 재계산(윤달은 평달 취급 — OPEN_QUESTIONS.md에
  출시 전 재확인 필요 항목으로 기록). 데이터 범위 밖이면 조용한 폴백 없이 안내 문구만 표시.
- `DateDetailSheet` 편집 다이얼로그에 일정 종류(일반/기념일/생신/기일) 드롭다운과, 생신/기일
  선택 시에만 노출되는 "음력 기준" 스위치를 추가해 실제로 F8 대상 일정을 등록/편집할 수 있게
  배선. 홈 화면 앱바에 진입 아이콘 추가.
- 신규 위젯 테스트(`test/ui/anniversary_basis_converter_test.dart`, 5건): 기일/생신 필터링 및
  음력 배지 표시, 빈 상태 안내, 절기 계산값 배지 표시/미표시(KASI 실측 대비), 변환기 화면 렌더링.
- QA: `flutter analyze` 오류 0(기존 무해한 info 2건만), `flutter test` **35/35 통과**,
  `flutter build apk --debug` 빌드 성공.

### Phase 9 이후 — 여전히 미착수 (다음 라운드로 이월)
- 홈 화면 위젯 2종(음력/일진 요약, 다가오는 기념일) — "오늘 날짜" 1종과 동일한 Android
  AppWidgetProvider 패턴으로 추가 가능.
- 비트팩 바이너리(.bin+CRC32) 포맷 전환.
- §13 L1/L4 전수검증(KASI 실측 구간·계산 보완 구간 각각의 대규모 자동화 검증).

## Phase 10 — 마무리 라운드: 위젯 2종·비트팩 바이너리(음력)·§13 전수검증 (완료, 세부 스코프 조정)
- **위젯**: `MonthlyCalendarWidgetProvider`에 음력/일진 요약 텍스트 추가, 신규
  `UpcomingAnniversaryWidgetProvider`(다가오는 기일/생신) 추가. `lib/data/widget/widget_data_sync.dart`
  가 `DayInfoProvider`/이벤트 목록으로 요약 문자열을 계산해 shared_preferences에 쓰고,
  `MainActivity`의 MethodChannel(`com.baruncal.barun_calendar/widget#refresh`)로 네이티브
  브로드캐스트를 트리거해 `AppWidgetManager.ACTION_APPWIDGET_UPDATE`를 즉시 보낸다. 앱 시작
  시(`main.dart`)와 홈 화면 일정 변경 시(`HomeScreen.onEventsChanged`) 모두 동기화된다.
  세 번째 위젯 종류는 시간 제약으로 미착수(OPEN_QUESTIONS.md #1 참고).
- **비트팩 바이너리**: `tool/build_binary_tables.py`가 `lunar_table.json`(일 단위 KASI 실측)을
  음력연 단위로 그룹핑해 명세 §4-2 포맷 그대로 `assets/data/lunar_1899_2050.bin`(624바이트,
  magic "BLUN", version 1, startYear 1899, count 152, CRC32)으로 인코딩한다.
  `lib/domain/calendar/binary_lunar_table.dart`가 magic/version/CRC32를 검증하고 실패 시
  즉시 예외(K5, 조용한 폴백 금지)를 던지는 디코더. 절기 바이너리는 KASI confirmed 요구사항과
  실제 데이터 범위가 충돌해 미변환(OPEN_QUESTIONS.md #1 상세). 디코더는 검증된 독립 아티팩트로
  존재하며 아직 런타임 조회 경로에는 연결하지 않았다(리스크 관리).
- **§13 전수검증**: `test/calendar/kasi_full_verification_test.dart` 신규.
  - L4: `lunar_table.json` 전체(55,517일, 명세 요구 55,153일 상회)에 대해
    `solarToLunar`→`lunarToSolar` 왕복 항등 100% 일치 확인.
  - L1: `solarterm_table.json` 전체(696건, KASI 확정 제공 구간 2000~2028)에 대해
    `KasiSolarTermDataSource`가 원본과 100% 일치하고 `isComputedFallback == false`임을 확인.
- QA: `flutter analyze` 오류 0(기존 무해한 info 2건만), `flutter test` **43/43 통과**
  (binary_lunar_table_test.dart 6건 + kasi_full_verification_test.dart 2건 신규),
  `flutter build apk --debug` 빌드 성공(신규 네이티브 위젯 코드 포함).

### Phase 10 이후 — 남은 진짜 차이 (OPEN_QUESTIONS.md #1 요약 참고)
1. 절기·공휴일·잡절 KASI 확정 범위 자체 한계(2000~2028/2004~2028) — 데이터 소스 문제, 코드
   문제 아님.
2. 절기 비트팩 바이너리 미전환, 음력 바이너리는 런타임 미연결(검증 아티팩트로만 존재).
3. 위젯 3종 중 2종만 구현.
이 세 가지를 제외한 F1~F20 전 기능은 구현·QA 완료.

## Phase 11 — KASI 매년 자동 재조회 + GitHub Pages 공휴일 호스팅 + 위젯 3/3 (완료)
- `.github/workflows/kasi-yearly-refresh.yml`: 매년 1월 2일(KST 10시) cron + 수동 실행 지원.
  `tool/fetch_kasi_data.py`(기본 범위 올해-1~올해+5) → `build_kasi_assets.py` →
  `build_binary_tables.py` 순서로 실행하고 `assets/data`/`docs/data` 변경분을 PR로 올린다
  (직접 push 없음). 서비스키는 `secrets.KASI_SERVICE_KEY`로만 주입.
- `tool/build_kasi_assets.py`에 `publish_holidays_to_docs()` 추가 — `holiday_table.json`을
  구울 때마다 `docs/data/holidays/<year>.json`도 함께 재생성. `lib/data/config/remote_config.dart`
  기본 URL을 GitHub Pages 형태(`https://<org>.github.io/<repo>/data/holidays`)로 변경.
- `MonthMiniWidgetProvider`(Kotlin) + `widget_month_mini.xml`/`month_mini_widget_info.xml`
  신규: 명세 §7 W3(월간, 4×4)에 대응하는 "이번 달 미니 캘린더" 위젯. `WidgetDataSync._monthMiniGrid()`
  가 요일 헤더 + 오늘(`*`)/휴일(`.`) 표시가 있는 고정폭 텍스트 그리드를 계산해
  shared_preferences에 쓴다. `MainActivity`의 위젯 갱신 브로드캐스트 대상에 추가. 이로써
  명세가 정의한 위젯 3종(오늘/다가오는 기일생신/이번 달 미니 캘린더)이 모두 구현됨.
- 신규 테스트: `test/data/widget_data_sync_test.dart` 2건.
- QA: `flutter analyze` 오류 0(기존 무해한 info 2건만), `flutter test` **45/45 통과**,
  `flutter build apk --debug` 빌드 성공.

### Phase 11 이후 — 남은 진짜 차이 (OPEN_QUESTIONS.md 요약 참고)
1. 24절기·공휴일·잡절 KASI 확정 범위 한계(2000~2028/2004~2028) — 자동 재조회 워크플로우로
   앞으로 점진적으로 넓어짐(KASI_SERVICE_KEY secret 등록 필요).
2. 절기 비트팩 바이너리 미전환, 음력 바이너리는 런타임 미연결(검증 아티팩트로만 존재).
3. §13 전수검증은 확보된 실측 범위 내 100% 통과, 전체 범위는 데이터 부재로 불가.
F1~F20 전 기능(위젯 3종 포함)은 구현·QA 완료.

## Phase 12 — 경쟁 앱("만능달력 - 음력,손없는날,디데이,일정") 리뷰 기반 개선

Google Play(`com.life.lunarCal`, 개발사 Bioplus, 4.4★/리뷰 834개) 실제 사용자 리뷰를 조사(claude-in-chrome로
Play 스토어 리뷰 섹션 직접 열람)한 뒤, 바른달력 명세와 대조해 **명세에 없던 것만** 골라 반영했다.

- **조사 결과 요약**:
  - 리뷰1(H Vincent, 공감 553— 최다 공감): 음력/양력 전환·윤달·이삿날(손없는날) 체크 후 바로
    디데이로 등록하는 흐름이 편리하다는 호평. **개선 요청: "기념일에 사진넣기 기능"**.
  - 리뷰2(이경우, 공감 256): 디자인·조작 호평. 요청: 위젯 제공, 음력 일정 반복 기능.
  - 리뷰3(SEONG CHUL CHO, 공감 46): 반복 주기(1/3/6개월/1년)를 세부 설정하지 못해 매번
    재등록해야 하는 불편, 날짜 숫자 글씨가 흐려서 육안 식별이 어렵다는 불만.
  - **대조 결과**: 위젯(F5, 3종 완료)·음력 반복(F3, 매년 음력 반복 이미 구현)·큰글씨(F7)는
    바른달력 명세에 이미 있어 중복 작업 생략. **"기념일 사진 첨부"만 명세·구현 어디에도
    없는 진짜 공백**이었다(가장 공감 많은 요청이기도 함) — 이것만 신규 구현.
    반복 주기 세분화(N개월 간격)와 날짜 숫자 대비 개선은 이미 F3(반복)·F7(큰글씨 3단계)로
    선제 대응되어 있다고 판단해 별도 작업하지 않음(OPEN_QUESTIONS.md 신규 항목 참고).

- **구현: 일정/기념일 사진 첨부**
  - `CalendarEvent.photoPath`(String?, 앱 전용 저장소 내 로컬 파일 경로) 필드 추가
    (`lib/domain/event/event.dart`) — `copyWith`에 `clearPhoto` 플래그로 명시적 삭제 지원,
    `toJson`/`fromJson` 왕복 보존.
  - `lib/data/event/event_photo_store.dart` 신규: `image_picker`로 갤러리에서 사진을 골라
    앱 전용 `event_photos/` 디렉터리로 복사하고 경로를 반환, 더 이상 참조되지 않는 파일은
    `delete()`로 정리. pubspec에 `image_picker ^1.2.0`, `path_provider ^2.1.5` 추가.
  - `lib/ui/date_detail/date_detail_sheet.dart`: 일정 편집 다이얼로그에 "사진 추가/변경/삭제"
    행과 120px 미리보기, 일정 목록 `ListTile`에 40×40 썸네일(leading) 추가.
  - `lib/ui/home/home_screen.dart`: 일정 삭제 시 첨부 사진 파일도 함께 정리(고아 파일 방지).
  - iOS 프로젝트가 없는(Android 전용) 저장소라 `Info.plist` 권한 설정은 불필요, Android는
    최신 `image_picker`가 시스템 포토 피커를 사용해 별도 매니페스트 권한 추가 없이 동작.
  - 신규 테스트 2건(`test/domain/event_recurrence_test.dart`): 사진 경로 JSON 직렬화 보존,
    `clearPhoto` 동작.
  - QA: `flutter analyze` 오류 0(기존 무해한 info 2건만 그대로), `flutter test` **47/47 통과**
    (기존 45 + 신규 2), `flutter build apk --debug` 빌드 성공.

## Phase 13 — AdMob/Play Console 실계정 연동 (seolasoft@gmail.com)

- Chrome 자동화로 seolasoft@gmail.com 계정에 AdMob 앱("바른달력", Android) 및 배너 광고
  단위를 실제로 생성, Play Console에도 "바른달력"(`com.baruncal.barun_calendar`, 무료) 앱을
  신규 등록 완료(둘 다 사용자가 이미 로그인/결제수단 등록해둔 계정 사용).
  - AdMob 앱 ID: `ca-app-pub-6861868748362641~8163440323`
  - 배너 광고 단위 ID: `ca-app-pub-6861868748362641/2876092653`
- `android/app/src/main/AndroidManifest.xml`의 AdMob 앱 ID를 테스트값에서 위 실 앱 ID로
  교체(앱 ID는 Google 공식 가이드상 매니페스트에 항상 정적으로 두는 값이라 debug/release
  구분 없이 고정).
- `lib/ui/ads/ad_banner.dart`: `kReleaseMode`로 분기해 **디버그/프로파일 빌드는 항상
  Google 공식 테스트 배너 ID**, **릴리즈 빌드만 실제 배너 광고 단위 ID**를 쓰도록 변경.
  개발 중 실수로 실광고를 클릭해 무효 트래픽으로 계정이 정지되는 사고를 방지하기 위함.
  광고 단위 ID는 APK 디컴파일로 누구나 확인 가능한 공개 식별자라(KASI 서비스키와 달리)
  하드코딩해도 안전하다고 판단해 그대로 상수로 둠.
- QA: `flutter analyze` 오류 0(기존 무해 info 2건만), `flutter test` **47/47 통과**,
  `flutter build apk --debug` 성공, `flutter build apk --release` 성공(57.5MB, 디버그
  키스토어로 로컬 서명 — 실제 스토어 업로드용 릴리즈 키스토어는 별도 필요).
- Play Console 앱은 등록만 됐고 스토어 등재 정보(짧은/긴 설명, 스크린샷, 아이콘/피처
  그래픽, 개인정보처리방침 URL, 콘텐츠 등급 설문, 데이터 보안 섹션)는 아직 비어 있어
  실제 심사 제출은 불가능한 상태 — OPEN_QUESTIONS.md에 신규 항목으로 기록.

## Phase 14 — 사용자 리뷰 반영: 손없는날 표시 + 디데이 정렬 확인

- **손없는날(C-18)**: 명세에 규칙은 정의돼 있었으나(설정 8종 표시 항목 중 하나로 계획됨)
  실제 코드에는 판정 로직도 UI 노출도 전혀 없던 상태였다. 이번에 신규 구현:
  - `lib/domain/calendar/day_info.dart`: `isSonEobsneunDay(LunarDate)` 순수 함수(음력
    일자 끝자리 9 또는 0 → true, 윤달 여부 무관) + `DayInfo.isSonEobsneun` getter(음력
    정보 없으면 null — 조용한 폴백 없음, 기존 K5 원칙 유지).
  - `lib/data/settings/settings_repository.dart`: `AppSettings.showSonEobsneun` 필드
    추가(기본값 **false**, 명세 C-18 "기본 표시 OFF" 그대로).
  - `lib/ui/settings/settings_screen.dart`: "손없는날 표시" 토글 추가.
  - `lib/ui/home/home_screen.dart`: `HomeScreen`이 `settings`를 받아 토글 켜졌을 때만
    날짜 셀에 "손없는날" 배지 표시. `lib/main.dart`에서 `settings: _settings` 전달.
  - `lib/ui/date_detail/date_detail_sheet.dart`: 해당일이 손없는날이면 "오늘은
    손없는날입니다" 문구 표시(설정 토글과 무관하게 상세 시트에서는 항상 노출 — 날짜상세는
    이미 사용자가 그 날짜를 들여다보기로 선택한 맥락이라 숨길 이유가 없다고 판단).
  - `lib/ui/converter/converter_screen.dart`: 양력→음력 변환 결과 카드에 "손없는날/손없는날
    아님" 표시 추가(명세 §S6 목업 문구 그대로).
  - 신규 테스트 `test/calendar/son_eobsneun_test.dart` 5건: 판정 경계값(9/10/19/20/29/30
    true, 그 외 false), 윤달 무관, `DayInfo.isSonEobsneun` null/값 케이스.
  - 참고: `showGanji`/`showLunar`/`showSolarTerm`/`showHoliday` 등 기존 표시 항목 토글은
    설정 화면에만 존재하고 홈 캘린더 렌더링에는 애초에 연결돼 있지 않았다(일진은 항상
    무조건 표시). 이번 작업 범위가 아니라 손대지 않았음 — OPEN_QUESTIONS.md에 기록.
- **디데이(기일·생신) 최신순 정렬**: 확인 결과 이미 올바르게 구현돼 있었다.
  `lib/ui/anniversary/anniversary_screen.dart`의 `_nextOccurrenceFor`가 올해 발생일이
  이미 지났으면 내년 발생일로 넘어가 계산하고(음력 반복은 `lunarOccurrenceInYear` 사용),
  `_load()`에서 D-day 오름차순(계산 불가 항목은 뒤로) 정렬한다. 홈 화면 "다가오는 기일·생신"
  위젯(`lib/data/widget/widget_data_sync.dart`)도 동일하게 가장 가까운 1건을 뽑는 로직을
  이미 쓰고 있어 추가 수정 불필요 — 신규 코드 없음, 회귀 없는지만 기존 테스트로 재확인.
- QA: `flutter analyze` 오류 0(기존 무해 info 2건만), `flutter test` **52/52 통과**
  (기존 47 + 신규 5), `flutter build apk --debug` 빌드 성공.

## Phase 15 — 사용자 실사용 피드백 3건 반영 (다음 달 버튼, 음력 반복 자동 변환, 유연한 반복 주기)

사용자가 실제 앱을 써보고 지적한 세 가지를 확인·수정:

1. **"다음 달로 이동 버튼이 없다"**: 코드상 버튼은 이미 있었으나(AppBar leading에
   `chevron_left`, actions 맨 앞에 `chevron_right`) leading 자리가 관례상 "뒤로가기"로
   오인되기 쉽고, next 버튼도 다른 아이콘들 사이에 묻혀 눈에 띄지 않았을 것으로 판단.
   `lib/ui/home/home_screen.dart`: AppBar 타이틀을 "◀ 2026년 8월 ▶" 형태로 재구성(월 이동
   버튼을 타이틀 중앙에 명확히 배치), 타이틀 탭 시 `showDatePicker`로 연/월 직접 점프도
   추가. 캘린더 그리드에 좌우 스와이프 제스처(`GestureDetector.onHorizontalDragEnd`)도
   붙여 다음/이전 달 이동 경로를 이중화했다.

2. **"음력 일정을 등록하면 매년 자동으로 양력 변환되어야 하는데 안 되는 것 같다"**:
   실제 버그였다. `CalendarEvent.occurrencesInYear`(홈 캘린더 표시·알림 스케줄링에 쓰이던
   메서드)는 `isLunar`를 전혀 고려하지 않고 등록 당시의 양력 월/일을 그대로 매년
   반복하고 있었다 — `lunarOccurrenceInYear`라는 올바른 변환 메서드가 이미 있었지만
   `anniversary_screen.dart`/`widget_data_sync.dart`(위젯)에서만 쓰이고, 정작 홈 캘린더
   그리드와 알림 재예약 로직은 쓰지 않고 있었다. 수정:
   - `event.dart`에 `occurrencesInYearResolved(year, {lunarSource})` 추가 — isLunar &&
     yearly && lunarSource != null이면 `lunarOccurrenceInYear`로 그 해의 실제 변환일을
     구하고, 아니면 기존 로직으로 안전 폴백.
   - `home_screen.dart`(`_eventsOn`/캘린더 인덱스), `notification_service.dart`
     (`rescheduleForEvent`/`cancelForEvent`)가 이 resolved 버전을 쓰도록 교체 — 이제
     캘린더 표시와 알림도 매년 실제 음력→양력 변환일을 따라간다.
   - **음력 날짜를 직접 입력하는 UI 신규 추가**: 기존엔 "양력 날짜를 고른 뒤 음력
     스위치 켜기" 방식이라 사용자가 아는 음력 생일(예: 음력 3월 15일)을 직접 입력할
     방법이 없었다. `date_detail_sheet.dart`에 "음력 날짜로 생신·기일 등록" 버튼 추가 →
     음력 월/일 드롭다운 + 윤달 체크박스 + 실시간 "올해 양력 XX월 XX일" 미리보기 다이얼로그.
     선택 즉시 `lunarToSolar`로 변환해 등록되고 recurrence=yearly, isLunar=true로
     저장되어 매년 자동 반영된다. 존재하지 않는 음력 날짜(데이터 범위 밖 등)는 미리보기에
     빨간 경고를 띄우고 등록 버튼을 비활성화(조용한 폴백 금지).
   - 일정 목록·편집 다이얼로그에 "음력 O월 O일 기준" 라벨과 캘린더 셀의 이벤트 점 색을
     구분(보라=음력 반복, 주황=일반)해 사용자가 눈으로 확인 가능하게 했다.

3. **"반복 주기를 더 유연하게 설정하고 싶다"**: `RecurrenceType`에 `custom` 추가,
   `RecurrenceUnit { day, week, month }` + `customInterval`(N)을 `CalendarEvent`에 추가.
   "매 N일/매 N주/매 N개월"을 일정 추가·수정 다이얼로그에서 직접 지정 가능. 다단 알림도
   동일한 발생 계산 로직을 타므로 커스텀 주기에 맞춰 자동 재예약된다(매번 재등록 불필요).

**하위 호환성**: 기존 저장된 일정 JSON에는 `customUnit`/`customInterval` 키가 없다.
`fromJson`에서 `customUnit`은 없으면 null, `customInterval`은 없으면 1로 기본값
처리되어 기존 반복 없음/매년/매월 일정은 그대로 정상 동작한다(회귀 테스트로 검증).

QA: `flutter analyze` 오류 0(기존 무해 info 2건만), `flutter test` **56/56 통과**
(신규 4건: 커스텀 일/월 간격 반복, resolved 음력 자동변환 검증, 구버전 JSON 하위호환),
`flutter build apk --debug` 빌드 성공.

## Phase 14: 병렬 fork 정합성 점검 및 표시 토글 버그 수정

두 개의 병렬 fork(손없는날+디데이 정렬 / 월이동+음력자동변환+커스텀반복)가 동시에
같은 파일들(home_screen.dart, date_detail_sheet.dart, event.dart 등)을 수정한 뒤,
실제 파일 상태를 재검증했다. 결과: 두 fork의 변경사항이 모두 유실 없이 살아있었다
(son_eobsneun_test.dart 5건 + event_recurrence_test.dart 등 신규 테스트가 최종
`flutter test` 56/56에 전부 포함되어 실행됨을 확인).

추가로 OPEN_QUESTIONS.md에 기록되어 있던 버그(설정 화면의 showGanji/showLunar/
showSolarTerm/showHoliday 토글이 홈 캘린더 렌더링에 연결되지 않아 꺼도 항상 표시되던 문제)를
이번에 실제로 고쳤다. `lib/ui/home/home_screen.dart`의 날짜 셀 렌더링에서 네 개 설정값을
모두 읽어 일진/음력/절기/공휴일 표시 여부와 공휴일 색상 강조를 제어하도록 반영.

QA: `flutter analyze` 오류 0(기존 무해 info 2건만), `flutter test` **56/56 통과**,
`flutter build apk --debug` 빌드 성공.

## Phase 15: Play Console 프로덕션 등록용 산출물 준비 (스토어 자산·서명키·설명문)

Play 스토어 프로덕션 등재를 위해 필요한 산출물을 준비했다(Play Console 웹 UI 조작은
오케스트레이터가 Chrome 자동화로 별도 진행):

1. **개인정보처리방침**: `docs/privacy-policy.html` — 로컬 저장/AdMob 광고ID/인앱결제/
   민감정보 미수집을 명시한 한국어 방침. GitHub Pages `docs/` 구조에 맞춰 작성(실제 배포는
   저장소 생성 후).
2. **스토어 등재 문구**: `store_listing_ko.md` — 앱 제목(검색 키워드 "음력·만세력·손없는날"
   포함, 17자), 짧은 설명(48자), 전체 설명, 카테고리 추천(라이프스타일), 콘텐츠 등급 설문
   초안(전체이용가 목표), 데이터 보안(Data safety) 설문 초안.
3. **그래픽 자산**: `store_assets/icon_512.png`(앱 아이콘 512×512, 알파 제거),
   `store_assets/feature_graphic_1024x500.png`(신규 생성), `store_assets/screenshots/`
   (디자인 핸드오프 스크린샷 6장, 924×540 — 실제 기기 캡처가 아닌 디자인 목업 기반이라는
   한계 있음, OPEN_QUESTIONS 참고).
4. **릴리즈 서명 키**: `~/.android-keystores/baruncal-upload.jks`(alias `baruncal-upload`,
   프로젝트 리포 밖에 보관) 신규 생성, 비밀번호는 `~/.android-keystores/
   baruncal-upload-key-info.txt`에 기록(프로젝트 밖, 권한 600). `android/key.properties`
   (gitignore 처리됨, 이미 템플릿에 포함돼 있었음)로 `android/app/build.gradle.kts`가
   release 서명을 읽도록 구성. `flutter build appbundle --release` 실행 결과
   `build/app/outputs/bundle/release/app-release.aab`(58.3MB) 서명 빌드 성공.

QA: HTML 파싱 검증 통과, 이미지 규격(512×512 무알파, 1024×500, 924×540 스크린샷 6장)
확인, AAB 빌드 성공.

## Phase 16: 최초 실행 온보딩(코치마크) — 2026-08-13

사용자가 "처음 보는 사용자들이 어떻게 사용하는지 알 수 있게 화면 위에 덮이는 스케치 같은 걸로
안내해달라"고 요청 — 업계에서 "코치마크(coach mark)" 또는 "스포트라이트 온보딩"이라 부르는
패턴이다.

- `lib/ui/onboarding/coach_mark_overlay.dart`: 외부 패키지 없이 `Overlay` + `CustomPainter`
  (Path.combine으로 스포트라이트 구멍을 뚫는 방식)로 직접 구현. 단계별 말풍선 + 다음/건너뛰기/
  시작하기 버튼.
- `lib/data/onboarding/onboarding_repository.dart`: SharedPreferences 기반 완료 여부 저장
  (기존 `SharedPrefsSettingsRepository` 패턴과 동일 구조).
- 최초 실행 시 홈 화면 진입 직후 5단계(월 이동 → 날짜 셀 → 기일/생신 → 검색 → 설정)를 순서대로
  강조. 완료/건너뛰기 시 완료 플래그 저장, 이후 재실행되지 않음.
- 설정 화면 "도움말" 섹션에 "사용법 다시 보기" 메뉴 추가 — 완료 플래그와 무관하게 강제 재실행.
- 다크모드/글자배율 등 기존 테마 체계를 그대로 따름(별도 스타일 하드코딩 없음).
- `test/ui/onboarding_coach_mark_test.dart` 4건 추가: 최초 표시, 완주 후 미표시, 건너뛰기,
  설정에서 재실행.
- QA: `flutter analyze` 오류 0(기존 info 2건만), `flutter test` **60/60 통과**,
  `flutter build apk --release` 빌드 성공. 실기기(Galaxy, Android 13) 재설치 후 크래시 0건,
  온보딩 코치마크 정상 표시 확인(Phase 15의 R8/WorkManager 크래시 수정이 유지됨을 재확인).
