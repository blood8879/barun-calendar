import '../calendar/day_info.dart';

enum EventKind { normal, anniversary, birthday, memorial }

// custom: 사용자가 임의 간격(N일/N주/N개월)을 지정하는 반복. 경쟁 앱 리뷰에서
// "반복 주기를 매번 재등록해야 해서 불편하다"는 지적에 대응해 추가됨.
enum RecurrenceType { none, yearly, monthly, custom }

enum RecurrenceUnit { day, week, month }

class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final bool isLunar; // 음력 기준 일정 여부 (반복 시 매년 음력 날짜 추적)
  final EventKind kind;
  final String? memo;
  final RecurrenceType recurrence;
  // recurrence == custom일 때만 사용. 예: unit=week, interval=2 → 2주마다.
  final RecurrenceUnit? customUnit;
  final int customInterval;
  // 알림 시각: 일정 당일 0시 기준 '몇 분 전'에 울릴지의 목록 (다단 알림, F4)
  final List<int> reminderMinutesBefore;
  // 기념일/생신 등에 첨부한 사진의 로컬 파일 경로. 경쟁 앱 리뷰(최다 공감 553)의
  // "기념일에 사진넣기 기능" 요청에 대응해 추가됨. 앱 전용 저장소에 복사된 파일만 가리킨다.
  final String? photoPath;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.isLunar = false,
    this.kind = EventKind.normal,
    this.memo,
    this.recurrence = RecurrenceType.none,
    this.customUnit,
    this.customInterval = 1,
    this.reminderMinutesBefore = const [],
    this.photoPath,
  });

  bool get notify => reminderMinutesBefore.isNotEmpty;

  CalendarEvent copyWith({
    String? title,
    DateTime? date,
    bool? isLunar,
    EventKind? kind,
    String? memo,
    RecurrenceType? recurrence,
    RecurrenceUnit? customUnit,
    bool clearCustomUnit = false,
    int? customInterval,
    List<int>? reminderMinutesBefore,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      isLunar: isLunar ?? this.isLunar,
      kind: kind ?? this.kind,
      memo: memo ?? this.memo,
      recurrence: recurrence ?? this.recurrence,
      customUnit: clearCustomUnit ? null : (customUnit ?? this.customUnit),
      customInterval: customInterval ?? this.customInterval,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  /// 이 일정이 [year]년에 실제로 발생하는 날짜(반복 규칙 적용).
  /// - none: date.year == year 인 경우에만 그 날짜.
  /// - yearly: 매년 같은 월/일(양력 기준 반복). [isLunar]인 경우의 실제 매년 음력→양력
  ///   변환은 이 메서드가 아니라 [occurrencesInYearResolved](lunarSource 필요)를 써야 한다.
  /// - monthly: 해당 연도의 매월 같은 일자(윤년 2/29 등 존재하지 않는 날은 건너뜀).
  /// - custom: [customUnit]/[customInterval]로 지정한 임의 간격(N일/N주/N개월) 반복.
  List<DateTime> occurrencesInYear(int year) {
    if (recurrence == RecurrenceType.none) {
      return date.year == year ? [date] : [];
    }
    if (year < date.year) return [];
    if (recurrence == RecurrenceType.yearly) {
      final daysInTargetMonth = DateTime(year, date.month + 1, 0).day;
      if (date.day > daysInTargetMonth) return [];
      return [DateTime(year, date.month, date.day)];
    }
    if (recurrence == RecurrenceType.custom) {
      return _customOccurrencesInYear(year);
    }
    // monthly
    final result = <DateTime>[];
    for (var month = 1; month <= 12; month++) {
      if (year == date.year && month < date.month) continue;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      if (date.day > daysInMonth) continue;
      result.add(DateTime(year, month, date.day));
    }
    return result;
  }

  List<DateTime> _customOccurrencesInYear(int year) {
    final unit = customUnit ?? RecurrenceUnit.month;
    final interval = customInterval < 1 ? 1 : customInterval;
    final result = <DateTime>[];
    if (unit == RecurrenceUnit.month) {
      var y = date.year;
      var m = date.month;
      var guard = 0;
      while (y <= year && guard < 5000) {
        guard++;
        final daysInM = DateTime(y, m + 1, 0).day;
        if (date.day <= daysInM) {
          final occ = DateTime(y, m, date.day);
          if (occ.year == year) result.add(occ);
        }
        m += interval;
        while (m > 12) {
          m -= 12;
          y += 1;
        }
      }
      return result;
    }
    // day/week 단위: 고정 일수 간격으로 등록일부터 순차 진행.
    final stepDays = unit == RecurrenceUnit.week ? 7 * interval : interval;
    var occ = date;
    var guard = 0;
    while (occ.year <= year && guard < 20000) {
      guard++;
      if (occ.year == year) result.add(occ);
      occ = occ.add(Duration(days: stepDays));
    }
    return result;
  }

  /// [occurrencesInYear]와 동일하되, [isLunar] && recurrence==yearly인 경우
  /// [lunarSource]로 그 해의 실제 음력→양력 변환일을 다시 계산해 반환한다.
  /// (매년 사용자가 직접 양력으로 변환해 재등록할 필요가 없도록 하기 위함.)
  /// [lunarSource]가 없으면 [occurrencesInYear]와 동일하게 동작한다(양력 월/일 그대로 반복).
  List<DateTime> occurrencesInYearResolved(
    int year, {
    LunarCalendarDataSource? lunarSource,
  }) {
    if (isLunar && recurrence == RecurrenceType.yearly && lunarSource != null) {
      final occ = lunarOccurrenceInYear(lunarSource, year);
      return occ != null ? [occ] : [];
    }
    return occurrencesInYear(year);
  }

  /// 특정 발생일 기준 알림 발송 시각 목록.
  List<DateTime> reminderTimesFor(DateTime occurrence) {
    return reminderMinutesBefore
        .map((m) => occurrence.subtract(Duration(minutes: m)))
        .toList();
  }

  /// 음력 기준 기일/생신(F8) 등의 [year]년도 실제 발생 양력 날짜.
  /// [isLunar]가 아니면 null. 원래 등록일의 음력 월/일을 [source]로 구해, 대상 연도의
  /// 같은 음력 월/일에 해당하는 양력 날짜를 다시 [source]로 조회한다(윤달은 평달로 취급).
  /// 데이터 범위 밖이거나 존재하지 않는 음력일이면 조용한 폴백 없이 null을 반환한다.
  DateTime? lunarOccurrenceInYear(LunarCalendarDataSource source, int year) {
    if (!isLunar) return null;
    final original = source.solarToLunar(date);
    if (original == null) return null;
    return source.lunarToSolar(year, original.month, original.day);
  }

  /// 반복 발생 1건에 대한 알림 스케줄링용 안정적 정수 ID (32bit 범위 내).
  int notificationIdFor(DateTime occurrence, int reminderIndex) {
    final key = '$id-${occurrence.year}${occurrence.month}${occurrence.day}-$reminderIndex';
    return key.hashCode & 0x7fffffff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'isLunar': isLunar,
        'kind': kind.name,
        'memo': memo,
        'recurrence': recurrence.name,
        'customUnit': customUnit?.name,
        'customInterval': customInterval,
        'reminderMinutesBefore': reminderMinutesBefore,
        'photoPath': photoPath,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String),
        isLunar: json['isLunar'] as bool? ?? false,
        kind: EventKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => EventKind.normal,
        ),
        memo: json['memo'] as String?,
        // 구버전 데이터(RecurrenceType.custom 도입 전)와의 하위 호환:
        // 알 수 없는 값이면 none으로 안전하게 폴백한다.
        recurrence: RecurrenceType.values.firstWhere(
          (r) => r.name == json['recurrence'],
          orElse: () => RecurrenceType.none,
        ),
        customUnit: json['customUnit'] != null
            ? RecurrenceUnit.values.firstWhere(
                (u) => u.name == json['customUnit'],
                orElse: () => RecurrenceUnit.month,
              )
            : null,
        customInterval: json['customInterval'] as int? ?? 1,
        reminderMinutesBefore: json['reminderMinutesBefore'] != null
            ? List<int>.from(json['reminderMinutesBefore'] as List)
            : (json['notify'] == true ? [0] : const []),
        photoPath: json['photoPath'] as String?,
      );
}
