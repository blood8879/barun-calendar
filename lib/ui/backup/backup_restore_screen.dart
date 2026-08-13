import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/event/event_repository.dart';
import '../../domain/event/event.dart';

/// 디자인 목업 S9(백업/복원) 대응 화면.
/// MVP 구현: 일정 데이터를 JSON으로 클립보드에 복사(내보내기) / 클립보드 JSON 붙여넣기(복원).
/// 실기기 파일 저장(공유 시트/파일 선택기) 연동은 OPEN_QUESTIONS.md에 남겨둔 후속 작업.
class BackupRestoreScreen extends StatefulWidget {
  final EventRepository eventRepository;

  const BackupRestoreScreen({super.key, required this.eventRepository});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _controller = TextEditingController();
  String? _message;

  Future<void> _export() async {
    final events = await widget.eventRepository.loadAll();
    final json = jsonEncode({
      'app': 'barun_calendar',
      'schemaVersion': 1,
      'events': events.map((e) => e.toJson()).toList(),
    });
    await Clipboard.setData(ClipboardData(text: json));
    setState(() => _message = '일정 ${events.length}건을 클립보드에 복사했습니다.');
  }

  Future<void> _restore() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _message = '복원할 JSON을 붙여넣어 주세요.');
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['events'] as List<dynamic>? ?? [];
      final events = list
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      await widget.eventRepository.replaceAll(events);
      setState(() => _message = '일정 ${events.length}건을 복원했습니다.');
    } catch (_) {
      // C-불일치 케이스(디자인 목업 X1-백업불일치): 형식이 다르면 조용히 무시하지 않고 명시적으로 알린다.
      setState(() => _message = '백업 형식을 확인할 수 없습니다. 손상되었거나 다른 앱의 파일입니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('백업 / 복원')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내보내기', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('현재 일정을 JSON으로 클립보드에 복사합니다.'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.copy_all),
              label: const Text('클립보드로 내보내기'),
            ),
            const SizedBox(height: 24),
            Text('복원', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('백업 JSON을 붙여넣으면 현재 일정을 대체합니다.'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"app":"barun_calendar", ...}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _restore,
              icon: const Icon(Icons.restore),
              label: const Text('붙여넣은 내용으로 복원'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
