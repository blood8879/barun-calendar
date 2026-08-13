import 'package:flutter/material.dart';

import '../../data/kasi/kasi_calendar_data_sources.dart';
import '../../domain/calendar/day_info.dart';

/// 디자인 목업 S3(근거) 대응 — 특정 날짜의 일진/음력/절기 산출 근거(KASI 공표 원문)를 보여준다.
class BasisScreen extends StatelessWidget {
  final DateTime date;
  final DayInfo dayInfo;
  final LunarCalendarDataSource lunarSource;

  const BasisScreen({
    super.key,
    required this.date,
    required this.dayInfo,
    required this.lunarSource,
  });

  @override
  Widget build(BuildContext context) {
    final source = lunarSource;
    final ganji = source is KasiLunarCalendarDataSource ? source.ganjiOn(date) : null;
    final rows = <(String, String)>[
      (
        '양력',
        '${date.year}.${date.month.toString().padLeft(2, '0')}.'
            '${date.day.toString().padLeft(2, '0')}',
      ),
      if (dayInfo.lunar != null) ('음력', dayInfo.lunar!.label),
      ('일진', ganji?['ilju'] ?? dayInfo.ilju),
      if (ganji != null) ('세차(年柱)', ganji['secha']!),
      if (ganji != null) ('월건(月柱)', ganji['wolgeon']!),
      if (dayInfo.solarTerm != null)
        (
          '24절기',
          dayInfo.solarTerm!.isComputedFallback
              ? '${dayInfo.solarTerm!.name} (계산값·비공식)'
              : dayInfo.solarTerm!.name,
        ),
      for (final h in dayInfo.holidays) (h.isOffDay ? '공휴일' : '기념일', h.name),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('근거')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            ganji == null
                ? '이 날짜는 확보된 KASI 데이터 범위 밖이라 원문 근거를 표시할 수 없습니다.'
                : '한국천문연구원(KASI) 공공데이터포털 「음양력 정보」·「특일 정보」 공표값을 그대로 표시합니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final r in rows)
                  ListTile(
                    dense: true,
                    title: Text(r.$1),
                    trailing: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          if (dayInfo.solarTerm?.isComputedFallback == true) ...[
            const SizedBox(height: 12),
            Text(
              '이 절기 값은 KASI 특일 정보 API 제공 범위(2000~2028년) 밖이라 자체 천문 계산'
              '(태양 겉보기 황경 기준)으로 보완한 값입니다. KASI 공식 공표값이 아닙니다.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.orange.shade800),
            ),
          ],
        ],
      ),
    );
  }
}
