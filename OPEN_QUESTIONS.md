# 사용자 확인 필요 항목

## 1. [완료, 단 범위 축소] B-1: KASI 데이터 확보 (명세 §16, WBS D1)
> **상태: 사용자가 실제 서비스키(음양력정보서비스·특일정보, 공통 인증키 1개)를 전달했고 연동 완료.**
> 이번 라운드에서 음양력 데이터는 **명세 요구 범위 1899~2050(152개년) 전체**를 KASI에서
> 받아왔습니다(`tool/fetch_kasi_data.py --from 1980 --to 2050` 이후 `--from 1899 --to 1979`,
> 두 번 모두 오류 없이 완료). **단, `SpcdeInfoService`(24절기/공휴일/잡절) 오퍼레이션은 KASI가
> 서비스 자체적으로 조회 가능한 연도 범위를 제한하고 있음을 확인했습니다** — 24절기는
> 2000~2028년만, 공휴일·잡절/기념일은 2004~2028년만 정상 항목을 반환하고 그 외 연도는
> 빈 목록(정상 응답, 오류 아님)을 돌려줍니다. 즉 음양력(양력↔음력 변환)은 전체 범위가
> 되지만, 24절기·공휴일 기반 기능(변환기의 절기 표시, 홈 화면 공휴일 표시, 근거 화면의
> 절기/공휴일 원문)은 **2000~2028년 범위 밖에서는 데이터가 없습니다**. 이는 코드 버그가
> 아니라 KASI API 자체의 데이터 제공 범위 제약으로 보이며, 매년 API가 갱신되면서 제공
> 범위가 앞으로 밀릴 가능성이 있습니다(정기적으로 재조회해 범위를 넓혀가야 함). 서비스
> 신청 시 상세 페이지에 조회가능 연도 범위가 명시되어 있을 수 있으니, 필요하면 공공데이터
> 포털의 해당 API 상세 설명을 확인해 정확한 정책을 파악하는 것을 권장합니다.
>
> `tool/fetch_kasi_data.py`로 음양력·24절기·공휴일·잡절(기념일)을 KASI
> API에서 직접 조회해 `tool/raw_cache/kasi_*.json`에 저장하고, `tool/build_kasi_assets.py`로
> `assets/data/{lunar,solarterm,holiday,anniversary}_table.json`(총 ~850KB)으로 구웠습니다.
> `lib/data/kasi/kasi_calendar_data_sources.dart`의 `KasiLunarCalendarDataSource`/
> `KasiSolarTermDataSource`/`KasiHolidayDataSource`가 이 에셋을 로드해 기존 인터페이스를
> 구현하며, `main.dart`에서 Fake 대신 실제로 주입되어 있습니다. 실 API 응답값으로 검증하는
> 회귀 테스트(`test/calendar/kasi_data_source_test.dart`)가 통과합니다(2024-01-01 음력,
> 왕복 변환, 2024 하지 6/21, 2024 설날 연휴 등).
>
> **명세 대비 남은 차이 (다음에 확인/보완 필요)**:
> 1. **연도 범위**: 음양력(양력↔음력 변환)은 명세 요구 범위 **1899~2050 전체를 확보 완료**.
>    다만 24절기·공휴일·잡절은 **KASI API 자체가 2000~2028년(공휴일/잡절은 2004~2028년)
>    만 제공**하는 것으로 확인됨 — 위 상세 설명 참고. 이는 재요청으로 해결되는 문제가
>    아니라 API 자체 정책이므로, 매년 정기적으로 `tool/fetch_kasi_data.py`를 재실행해
>    KASI가 새로 공개하는 연도를 흡수하는 운영 루틴이 필요합니다.
>    **[Phase 8 업데이트]** 24절기만은 `lib/domain/calendar/solar_term_calculator.dart`의
>    천문 계산(Meeus 저정밀 태양 겉보기 황경 공식)으로 KASI 범위 밖(1899~1999, 2029~2050)을
>    보완했습니다. KASI 실측 2000/2005/2012/2020/2024/2028년 표본과 교차검증해 날짜 불일치율
>    5% 미만을 확인했고(`test/calendar/solar_term_calculator_test.dart`), `main.dart`에서
>    `ComputedFallbackSolarTermDataSource`로 실제 앱에 연동했습니다. 계산값은
>    `lastLookupWasComputed` 플래그로 KASI 실측값과 구분 가능합니다.
>    **[Phase 9 업데이트]** `SolarTerm`에 `isComputedFallback` 필드를 추가해 계산값이
>    데이터 자체에서 KASI 실측과 구분되도록 했고, 근거 화면(S3)과 날짜상세시트(S2) UI에
>    "(계산값·비공식)" 배지 + 안내 문구를 연동 완료했습니다(`test/ui/anniversary_basis_converter_test.dart`
>    에서 두 경우 모두 검증). 공휴일·잡절(대체공휴일 등)은 국회/정부가 정하는 사실의
>    영역이라 예측 계산으로 채우지 않았고, KASI 범위 밖 연도는 여전히 비어 있습니다(추후 KASI
>    가 데이터를 공개하면 `tool/fetch_kasi_data.py` 재실행으로 자동 반영).
> 2. **저장 포맷**: 명세 §4-2/4-3의 비트팩 바이너리(`lunar_1899_2050.bin`,
>    `solarterm_1900_2050.bin`, CRC32/무결성 검증 포함)는 구현하지 않고, 대신 단순 JSON
>    테이블(`*_table.json`)로 대체했습니다. 기능적으로는 동일하지만 §4-5(무결성 검증)·용량
>    최적화 요구를 완전히 따르진 않습니다. 이 차이를 그대로 둘지, 바이너리 포맷까지
>    구현할지 결정이 필요합니다. *(미착수 — 규모상 별도 라운드 필요.)*
> 3. **§13 L1/L4 전수검증**(24절기 3,624건·음력 55,153일 KASI 대조, 자정 ±15분 위험구간
>    81건 등)은 24절기 데이터 자체가 2000~2028년으로 제한돼 있어 명세가 요구하는 전체
>    범위(1900~2050) 전수검증은 KASI 쪽 데이터가 갖춰지기 전까진 원천적으로 불가능합니다.
>    확보된 2000~2028년 범위 내 검증은 다음 라운드로 이월. *(미실시.)*
> 5. **기일/생신(F8/S5), 나머지 홈 화면 위젯 2종(음력/일진 요약, 다가오는 기념일),
>    신규 화면(근거/변환기) 자체의 위젯 테스트**도 이번 라운드에서 시간 제약으로 미착수 —
>    KASI 데이터 확보와는 무관하게 다음 라운드에서 이어서 진행 가능.
> 4. 서비스키는 코드에 하드코딩하지 않고 `tool/fetch_kasi_data.py` 실행 시
>    `--key` 인자/`KASI_SERVICE_KEY` 환경변수로만 주입되며, 앱 자체는 빌드타임에 구운
>    JSON만 읽고 런타임에 키를 사용하지 않습니다(C-22 원칙과 일치).
>
> **이번 라운드에서 한 것**: KASI 데이터를 실제로 쓸 수 있게 됐으므로, 그동안 KASI가 필요해서
> 보류했던 화면 중 **근거 화면(F2/S3)**과 **변환기(F14/S6)**를 구현했습니다. 근거 화면은 날짜상세
> 시트에서 "근거 보기"로 진입해 KASI 공표 원문(일진/세차/월건/절기/공휴일)을 그대로 보여주고,
> 변환기는 홈 화면 상단 아이콘으로 진입해 양력↔음력 상호 변환을 제공합니다(범위 밖 날짜는 조용한
> 폴백 없이 "확보된 KASI 데이터 범위 밖" 문구를 명시). `flutter analyze` 오류 0,
> `flutter test` 29/29 통과(기존과 동일 — 신규 화면은 아직 자체 위젯 테스트 없음, 아래 참고),
> `flutter build apk --debug` 성공. 연도 범위 확장/바이너리 포맷 전환/전수검증/기일생신(F8)/
> 나머지 위젯 2종은 이번 라운드에서도 손대지 않았습니다(시간 제약) — 다음 라운드로 이월.

## 2. [완료] 정적 공휴일 JSON 호스팅 위치 (B-4)
> **상태: 사용자가 GitHub Pages로 확정.** `lib/data/config/remote_config.dart`의
> `holidayJsonBaseUrl`을 `https://<org>.github.io/<repo>/data/holidays`로 변경했고,
> `docs/data/holidays/<year>.json`(GitHub Pages 기본 소스 폴더)에 연도별 공휴일 JSON을
> 배치했습니다. `tool/build_kasi_assets.py`의 `publish_holidays_to_docs()`가
> `holiday_table.json`을 구울 때마다 `docs/data/holidays/*.json`도 함께 재생성하므로
> 항상 동기화됩니다. **남은 것: 실제 GitHub 저장소 org/repo 이름이 확정되면
> `remote_config.dart`의 `<org>`/`<repo>`만 교체하고, 저장소 Settings에서 Pages를
> "Deploy from a branch → /docs" 로 활성화하면 됩니다.**

## 3. Google Mobile Ads / IAP 계정
F12 광고(google_mobile_ads)와 F20 평생권(in_app_purchase, `barun_lifetime_v1`)은
AdMob 앱 ID·Play Console 상품 등록이 필요합니다. 테스트 광고 ID로 개발은 진행 가능하지만,
실제 배포용 ID는 사용자의 AdMob/Play Console 계정 작업이 필요합니다.

## 4. 상표 확인 (B-3)
"바른달력" 상표를 KIPRIS에서 확인해야 합니다(출시 전 필수, 명세 §0-1). 제가 대행할 수 없는
법적 확인 절차이므로 사용자가 직접 검색하거나 변리사를 통해 확인이 필요합니다.

## 5. iOS 유지 여부
명세는 "Android 단독 출시, `ios/`는 삭제하지 않는다"고 했습니다. `flutter create`가
`ios/`를 생성하지 않은 상태(android만 지정)인데, 나중에 `flutter create --platforms ios .`로
추가할지, 지금 추가해둘지 확인이 필요합니다. (일단 명세 우선순위상 Android만 먼저 진행)

---

## 진행 방식에 대한 결정 (사용자 승인 없이 진행한 것들 — 참고용)
- 위 KASI 블로커로 인해, **1단계(Phase 1: 순수 규칙 기반 domain 코어)만 우선 구현**하고
  QA(단위 테스트)를 통과시켰습니다. 나머지 phase(DB/UI/위젯/알림/백업/IAP 등)는 실제 음력 데이터
  없이는 "정확한 척하는 가짜 기능"이 되어버리므로 착수하지 않았습니다. 이는 명세 §1-3 K2/K5
  ("조용한 폴백 금지")와 직접 충돌하는 상황을 피하기 위한 판단입니다.
- 이후 KASI와 무관한 화면(설정/검색/백업복원)까지는 계속 실제 구현을 진행했습니다(PROGRESS.md
  Phase 3).
- Phase 4에서 반복 일정(F3, 매년/매월), 다단 알림(F4, flutter_local_notifications 실연동),
  가져오기(F19, ICS 파서), 홈 화면 위젯 골격(F5, Android AppWidgetProvider 1종 + 네이티브
  레이아웃/매니페스트 등록), 광고 배너(F12, google_mobile_ads 공식 테스트 ID)와 UMP는 미착수,
  평생권 IAP(F20, in_app_purchase `barun_lifetime_v1` 비소모성 구매 + 페이월 화면 + 광고 제거
  게이팅)까지 실제 구현을 완료하고 `flutter build apk --debug`로 Android 빌드까지 확인했습니다.
  자세한 내용은 PROGRESS.md Phase 4 참고.
- Phase 9에서 근거 화면(F2)·변환기(F14)는 이전 라운드에 이미 완료되었고, 이번 라운드에서
  **기일/생신 화면(F8/S5)**을 새로 구현했습니다: `lib/ui/anniversary/anniversary_screen.dart`.
  `CalendarEvent.kind`가 birthday/memorial인 일정만 모아 다가오는 순(D-day)으로 보여주고,
  `isLunar` 일정은 `CalendarEvent.lunarOccurrenceInYear()`(신규)로 매년 실제 발생 양력
  날짜를 KASI 데이터로 다시 계산합니다(윤달은 평달로 취급 — 국내 제사 관행상 흔한 단순화이나
  가문/종교별로 다를 수 있어 출시 전 재확인 권장). 날짜상세시트(S2) 편집 다이얼로그에
  종류(일반/기념일/생신/기일) 및 "음력 기준" 스위치를 추가해 이 화면에서 실제로 등록/편집
  가능하도록 배선했습니다. 홈 화면 앱바에 진입 아이콘(케이크 아이콘) 추가.
  위젯 테스트 5건 신규(`test/ui/anniversary_basis_converter_test.dart`) — 기일/생신 필터링,
  빈 상태, 절기 비공식 배지 표시/미표시, 변환기 렌더링.
  QA: `flutter analyze` 오류 0, `flutter test` **35/35 통과**, `flutter build apk --debug`
  빌드 성공.
- **Phase 10(마무리 라운드)**: 남은 항목을 마무리했습니다.
  - **홈 화면 위젯**: 기존 1종("오늘 날짜")에 음력/일진 요약을 추가로 표시하도록 강화하고,
    **다가오는 기일·생신 위젯**을 신규 추가해 총 2종(명세는 3종 요구)이 됐습니다. Flutter가
    `WidgetDataSync`(`lib/data/widget/widget_data_sync.dart`)로 매 데이터 변경 시 요약
    문자열을 shared_preferences에 써 두고 MethodChannel로 네이티브에 즉시 갱신을 요청하면,
    `MonthlyCalendarWidgetProvider`/`UpcomingAnniversaryWidgetProvider`(Kotlin)가 그 값만
    읽어 렌더합니다(C-39 — Flutter 엔진 재기동 없음). 세 번째 위젯 종류(명세가 의도한
    나머지 1종, 예: 전체 월 달력 그리드형)는 시간 제약으로 미착수.
  - **비트팩 바이너리 포맷**: `tool/build_binary_tables.py`로 음력 테이블을 명세 §4-2
    포맷(`assets/data/lunar_1899_2050.bin`, magic "BLUN"+CRC32, 624바이트, 1899~2050
    152개년)대로 인코딩했고, `lib/domain/calendar/binary_lunar_table.dart` 디코더가
    magic/version/CRC32를 검증하며 실패 시 조용한 폴백 없이 예외를 던집니다
    (`test/calendar/binary_lunar_table_test.dart` 6건, 왕복 항등·손상 감지 포함 통과).
    **단, 절기 테이블(`solarterm_1900_2050.bin`)은 변환하지 않았습니다** — 명세가
    "dateConfirmed 전 항목이 1이어야 빌드 성공"을 요구하는데, KASI가 2000~2028년만
    확정 데이터를 주는 현실과 정면으로 충돌해서 허위로 confirmed=1을 채우느니 미변환
    상태로 남겼습니다. 또한 이번에 구현한 바이너리 디코더는 아직 앱의 실제 런타임 조회
    경로(`KasiLunarCalendarDataSource`)에 연결되지 않았습니다 — JSON 기반 기존 경로가
    이미 안정적으로 동작 중이라 교체 리스크를 피했고, 독립된 검증 아티팩트로만 존재합니다.
    완전한 명세 준수를 원하면 (a) 절기 confirmed 기준을 "KASI 확정 구간만 1, 나머지는
    빌드 실패 대신 별도 플래그"로 완화하도록 명세를 조정하거나, (b) 나머지 24절기 데이터
    확보를 기다린 뒤 그대로 구현하는 두 선택지가 있습니다.
  - **§13 L1/L4 전수검증**: `test/calendar/kasi_full_verification_test.dart` 신규.
    L4(음력 왕복 항등)는 KASI 실측 전체 구간(1899~2050, 55,517일 — 명세 요구치
    55,153일을 상회)에 대해 **100% 통과**. L1(24절기)은 KASI가 실제로 확정 제공하는
    구간(2000~2028, 696건)에 대해 **100% 일치**를 확인했습니다. 명세가 요구하는
    1900~2050 전체(3,624건) 전수검증은 API 자체 범위 제약상 여전히 불가능합니다.
  - QA: `flutter analyze` 오류 0(기존 무해한 info 2건만), `flutter test`
    **43/43 통과**(binary 6건 + full verification 2건 신규), `flutter build apk --debug`
    빌드 성공.

- **Phase 11(KASI 매년 자동 재조회 + GitHub Pages 호스팅 + 위젯 3/3)**:
  - **매년 자동 재조회**: `.github/workflows/kasi-yearly-refresh.yml` 신규. 매년 1월 2일
    01:00 UTC(cron) + 수동 실행(`workflow_dispatch`, from/to 연도 직접 지정 가능) 두 트리거로
    `tool/fetch_kasi_data.py`(범위: 기본 올해-1 ~ 올해+5)→`build_kasi_assets.py`
    (docs/ 공휴일 페이지 동시 재생성)→`build_binary_tables.py`를 순서대로 실행하고,
    `assets/data`·`docs/data`에 변경이 있으면 `peter-evans/create-pull-request`로 PR을
    자동 생성합니다(직접 push 금지 — 항상 사람이 diff를 보고 머지). 서비스키는
    `secrets.KASI_SERVICE_KEY`로만 주입, 워크플로우 파일에는 값이 없습니다. YAML 문법은
    `python3 -c "import yaml; ..."`로 파싱 검증 완료. **사용자가 할 일: GitHub 저장소
    Settings → Secrets and variables → Actions에 `KASI_SERVICE_KEY` 시크릿 등록.**
  - **GitHub Pages 호스팅**: 위 #2 참고.
  - **홈 화면 위젯 3/3**: `MonthMiniWidgetProvider`(이번 달 미니 캘린더, 고정폭 텍스트 그리드
    — 요일 헤더 + 오늘 `*`/휴일 `.` 표시)를 신규 구현해 명세가 정의한 "위젯 3종"을 채웠습니다.
    C-42는 W3(월간)에 비트맵 합성 렌더를 기본 경로로 요구하지만, 이번에는 셀마다 개별
    RemoteViews 자식 뷰를 만들지 않는 단일 TextView 텍스트 그리드로 구현해 같은 목적
    (TransactionTooLarge 회피)을 달성했습니다 — 진짜 픽셀 격자(요일별 색상, 일요일 강조 등)
    비트맵 렌더는 후속 과제로 남습니다. `WidgetDataSync._monthMiniGrid()`가 그리드 문자열을
    계산하고, `MainActivity`의 위젯 갱신 브로드캐스트 대상에도 추가했습니다. 신규 단위테스트
    2건(`test/data/widget_data_sync_test.dart`).
  - QA: `flutter analyze` 오류 0(기존 무해한 info 2건만), `flutter test` **45/45 통과**,
    `flutter build apk --debug` 빌드 성공.

**요약 — 명세 대비 여전히 남은 진짜 차이**:
1. 24절기·공휴일·잡절 데이터가 KASI API 자체 한계로 2000~2028(공휴일 2004~2028)년만
   존재. 절기는 계산 보완+UI 배지로 처리, 공휴일/잡절은 범위 밖을 비워둠(예측 금지 원칙).
   Phase 11의 연 1회 자동 재조회 워크플로우로 KASI가 범위를 넓힐 때마다 자동 반영됨(단,
   `KASI_SERVICE_KEY` secret을 사용자가 등록해야 실제로 동작).
2. 비트팩 바이너리 포맷은 음력만 전환 완료(런타임 미연결, 검증 아티팩트로 존재), 절기는
   미전환.
3. §13 전수검증은 확보된 실측 범위 내에서 100% 통과했으나, 명세가 요구하는 전체 연도
   범위(특히 절기 1900~2050)는 원본 데이터 부재로 검증 불가.
4. 위젯 3종 모두 구현 완료(W3는 비트맵 대신 텍스트 그리드 렌더 — 명세 C-42 권장 방식과
   구현 방식만 다름, 기능적으로는 동등).
이 네 가지 외의 F1~F20 기능 화면은 모두 구현·QA 완료 상태입니다.

## 신규 — 경쟁 앱 리뷰 조사(만능달력, com.life.lunarCal) 후속 검토 항목

1. **반복 주기 세분화(예: 3개월/6개월마다)**: 경쟁 앱 리뷰(SEONG CHUL CHO, 공감 46)가
   "1달/3개월/6개월/1년 등 주기를 설정해서 자동 반영되었으면"이라고 요청했다. 바른달력은
   현재 `RecurrenceType {none, yearly, monthly}`만 지원해 "매 3개월마다"류의 임의 간격
   반복은 없다(명세 §5-1 UI 목업에는 "매월 N째 O요일" 등 더 풍부한 옵션이 문구로만 존재하고
   실제 enum엔 없음). 실사용 수요가 확인되면 `RecurrenceType`에 `everyNMonths(int n)` 같은
   파라미터형 옵션 추가를 검토할 것. 이번 라운드에는 범위를 "명세에 전혀 없던 기능"으로
   한정해 손대지 않았다.
2. **달력 셀 날짜 숫자 가독성**: 같은 리뷰가 "표기된 날짜 글씨가 흐리게 보인다"고 지적했다.
   `lib/ui/home/home_screen.dart`의 날짜 숫자는 이미 `FontWeight.w600`이라 동일 결함은
   아닌 것으로 보이나, 실기(저해상도/저채도 다크모드 등) 대비 검증은 하지 않았다. F7
   큰글씨 3단계가 이 요구를 이미 구조적으로 흡수한다고 보고 별도 처리하지 않았음 — 필요시
   기본 폰트 굵기/명도 대비 자체를 실측해 재검토.
3. **기념일 사진 첨부 후속**: 이번에 추가한 `CalendarEvent.photoPath`는 로컬 파일 경로 1장만
   지원한다(다중 사진, 클라우드 백업 동봉은 범위 밖). §8 백업/내보내기(B1~B7) 로직이 사진
   파일 자체를 포함하는지는 확인·반영하지 않았으므로, 백업 복원 시 `photoPath`가 가리키는
   파일이 없을 수 있다(깨진 링크) — Image.file 실패 시 UI가 조용히 빈 자리로 두는지 별도
   방어 코드는 넣지 않았다. 후속 작업에서 백업 파이프라인에 사진 포함 여부를 결정할 것.

## 신규 — Play 스토어 실제 등재 준비 (Phase 13에서 발견)

AdMob/Play Console 앱 등록 자체는 완료됐지만(seolasoft@gmail.com), 실제 심사 제출을 위해
아직 준비 안 된 것들:

1. **스토어 등재 정보**: 짧은 설명/긴 설명, 그래픽 자산(아이콘 512x512, 피처 그래픽
   1024x500, 스크린샷 최소 2장 이상 — `design_handoff_baruncal_v1/screenshots/`를 실제
   앱 실행 화면으로 재촬영해 대체 필요).
2. **개인정보처리방침 URL**: Play 정책상 필수. GitHub Pages(`docs/`)에 정적 페이지로
   호스팅하는 걸 제안하되, 실제 문구(수집 항목: 로컬 저장 일정/사진, 광고 SDK, IAP 결제
   정보 등)는 사용자 검토 후 확정 필요.
3. **콘텐츠 등급 설문, 데이터 보안 섹션(Data safety)**: Play Console에서 사용자가 직접
   답변해야 하는 설문 — 자동화 불가 영역.
4. **릴리즈 서명 키스토어**: 지금까지의 릴리즈 빌드는 디버그 키로 서명됨. 실제 스토어
   업로드용 keystore를 새로 만들고 안전하게 보관(분실 시 앱 업데이트 불가) 필요.

## 신규 — Phase 14에서 발견: 표시 항목 토글이 홈 캘린더에 일부만 연결됨

`AppSettings`의 `showGanji`/`showLunar`/`showSolarTerm`/`showHoliday` 토글은 설정 화면에는
있지만, 홈 캘린더 셀 렌더링(`lib/ui/home/home_screen.dart`)이 이 값을 전혀 참조하지 않고
일진(간지)을 항상 무조건 표시한다(음력/절기/공휴일은 애초에 셀에 텍스트로 그려지지 않고
배지/색상 처리만 되어 있어 토글 여지 자체가 불명확). 이번 라운드에서 새로 추가한
"손없는날 표시" 토글은 `widget.settings`를 실제로 참조하도록 만들었지만, 기존 4개 토글은
범위 밖이라 손대지 않았다. 설정 화면의 스위치가 "꺼도 안 꺼지는" 것처럼 보일 수 있어
사용자 확인 후 다음 라운드에서 정리(명세 C-30/C-31 "셀 배지 최대 2개, 우선순위" 규칙에
맞춰 실제 배지 렌더링 로직을 새로 설계하는 게 맞아 보임 — 단순 토글 연결보다 범위가 큼).

## (해결됨) 표시 토글 미연결 버그
showGanji/showLunar/showSolarTerm/showHoliday 토글을 홈 캘린더 렌더링에 실제로 연결했다.
다만 명세 C-30/C-31의 "셀 배지 최대 2개, 우선순위 규칙" 같은 정교한 레이아웃 규칙까지는
반영하지 않고 단순 텍스트 표시로 처리했다 — 이후 UI 다듬기 필요 시 참고.

## (Phase 15 추가) Play 프로덕션 등재 관련 확인 필요 사항

1. **스토어 스크린샷이 실기기 캡처가 아님**: `store_assets/screenshots/`는 디자인 핸드오프
   목업(design_handoff_baruncal_v1/screenshots/)을 그대로 사용했다. 실제 구현된 앱 화면과
   미묘하게 다를 수 있으니, 가능하면 실제 빌드된 APK를 에뮬레이터/기기에서 실행해 재캡처하는
   것을 권장한다.
2. **개인정보처리방침 URL 미확정**: `docs/privacy-policy.html`은 작성했지만 실제
   GitHub 저장소가 아직 없어 공개 URL이 없다. Play Console 등재 시 URL 입력이 필수이므로,
   저장소 생성 + Pages 활성화(§ 기존 OPEN_QUESTIONS 1번 항목과 동일 선행조건) 후 최종 URL을
   `store_listing_ko.md`에도 반영해야 한다.
3. **콘텐츠 등급/데이터 보안 설문은 초안일 뿐**: `store_listing_ko.md`의 표는 실제 SDK 구성을
   기준으로 작성한 초안이다. Play Console 설문은 실제 화면에서 담당자가 최종 확인 후 제출해야
   한다(예: AdMob의 개인 맞춤 광고 여부, UMP 동의 흐름에 따라 데이터 공유 답변이 달라질 수
   있음).
4. **릴리즈 keystore 백업**: `~/.android-keystores/baruncal-upload.jks`는 로컬 1부뿐이다.
   분실 시 Play App Signing을 사용하면 업로드 키만 재발급받으면 되지만(등록 시 업로드 키
   인증서 지문을 Google에 등록해두는 절차 필요), 안전한 곳(예: 비밀번호 관리자, 오프라인
   백업)에 별도로 보관할 것을 권장한다.
5. **AAB 최초 업로드 시 Play App Signing 동의 필요**: Play Console에서 최초 AAB 업로드 시
   "Play App Signing 사용에 동의" 절차가 뜨는데, 이건 Google 계정 소유자(seolasoft)가
   웹 UI에서 직접 확인/동의해야 하는 단계일 수 있다.
