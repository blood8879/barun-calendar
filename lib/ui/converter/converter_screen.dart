import 'package:flutter/material.dart';

import '../../domain/calendar/day_info.dart';

/// 디자인 목업 S6(변환기) 대응 — 양력 <-> 음력 상호 변환.
class ConverterScreen extends StatefulWidget {
  final LunarCalendarDataSource lunarSource;

  const ConverterScreen({super.key, required this.lunarSource});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

enum _Mode { solarToLunar, lunarToSolar }

class _ConverterScreenState extends State<ConverterScreen> {
  _Mode _mode = _Mode.solarToLunar;
  DateTime _solarInput = DateTime.now();
  int _lunarYear = DateTime.now().year;
  int _lunarMonth = 1;
  int _lunarDay = 1;
  bool _isLeapMonth = false;

  LunarDate? get _lunarResult => widget.lunarSource.solarToLunar(_solarInput);
  DateTime? get _solarResult => widget.lunarSource.lunarToSolar(
        _lunarYear,
        _lunarMonth,
        _lunarDay,
        isLeapMonth: _isLeapMonth,
      );

  Future<void> _pickSolarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _solarInput,
      firstDate: DateTime(1899, 1, 1),
      lastDate: DateTime(2050, 12, 31),
    );
    if (picked != null) setState(() => _solarInput = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('변환기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(value: _Mode.solarToLunar, label: Text('양력→음력')),
                ButtonSegment(value: _Mode.lunarToSolar, label: Text('음력→양력')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 24),
            if (_mode == _Mode.solarToLunar) ...[
              OutlinedButton(
                onPressed: _pickSolarDate,
                child: Text(
                  '${_solarInput.year}.${_solarInput.month.toString().padLeft(2, '0')}.'
                  '${_solarInput.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _lunarResult != null
                            ? _lunarResult!.label
                            : '확보된 KASI 데이터 범위 밖이라 변환할 수 없습니다.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_lunarResult != null)
                        Text(
                          isSonEobsneunDay(_lunarResult!) ? '손없는날' : '손없는날 아님',
                          style: TextStyle(
                            color: isSonEobsneunDay(_lunarResult!) ? Colors.teal : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('lunar-year-field'),
                      decoration: const InputDecoration(labelText: '연도'),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: '$_lunarYear'),
                      onChanged: (v) => _lunarYear = int.tryParse(v) ?? _lunarYear,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('lunar-month-field'),
                      decoration: const InputDecoration(labelText: '월'),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: '$_lunarMonth'),
                      onChanged: (v) => _lunarMonth = int.tryParse(v) ?? _lunarMonth,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('lunar-day-field'),
                      decoration: const InputDecoration(labelText: '일'),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: '$_lunarDay'),
                      onChanged: (v) => _lunarDay = int.tryParse(v) ?? _lunarDay,
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('윤달'),
                value: _isLeapMonth,
                onChanged: (v) => setState(() => _isLeapMonth = v),
              ),
              FilledButton(
                onPressed: () => setState(() {}),
                child: const Text('변환'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _solarResult != null
                        ? '${_solarResult!.year}.${_solarResult!.month.toString().padLeft(2, '0')}.'
                            '${_solarResult!.day.toString().padLeft(2, '0')}'
                        : '해당 음력 날짜를 찾을 수 없습니다(범위 밖이거나 존재하지 않는 날짜).',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
