import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/event/event_repository.dart';
import '../../data/import/ics_parser.dart';

/// 디자인 목업 S10(가져오기) 대응 화면.
/// MVP 구현: 다른 캘린더 앱에서 내보낸 .ics 텍스트를 붙여넣어 일정으로 가져온다.
/// 실기기 파일 선택기(file_picker) 연동은 OPEN_QUESTIONS.md 후속 작업으로 남겨둔다.
class ImportScreen extends StatefulWidget {
  final EventRepository eventRepository;

  const ImportScreen({super.key, required this.eventRepository});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  String? _message;

  Future<void> _import() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _message = '가져올 ICS(iCalendar) 내용을 붙여넣어 주세요.');
      return;
    }
    if (!raw.contains('BEGIN:VEVENT')) {
      setState(() => _message = 'ICS 형식을 확인할 수 없습니다. VEVENT 항목이 없습니다.');
      return;
    }
    final result = parseIcs(raw, () => _uuid.v4());
    for (final event in result.events) {
      await widget.eventRepository.upsert(event);
    }
    setState(() {
      _message = result.events.isEmpty
          ? '가져올 수 있는 일정을 찾지 못했습니다.'
          : '일정 ${result.events.length}건을 가져왔습니다.'
              '${result.skippedCount > 0 ? ' (형식이 맞지 않는 ${result.skippedCount}건은 건너뜀)' : ''}';
      if (result.events.isNotEmpty) _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가져오기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('다른 캘린더 앱에서 내보낸 .ics 파일의 내용을 붙여넣으면 일정으로 가져옵니다.'),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'BEGIN:VCALENDAR\nBEGIN:VEVENT\n...',
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('가져오기'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
