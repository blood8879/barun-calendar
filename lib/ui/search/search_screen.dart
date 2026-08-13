import 'package:flutter/material.dart';

import '../../data/event/event_repository.dart';
import '../../domain/event/event.dart';

/// 디자인 목업 S7 대응 검색 화면. 제목/메모 텍스트로 일정을 찾는다.
class SearchScreen extends StatefulWidget {
  final EventRepository eventRepository;

  const SearchScreen({super.key, required this.eventRepository});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<CalendarEvent> _all = [];
  List<CalendarEvent> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await widget.eventRepository.loadAll();
    events.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _all = events;
      _results = events;
      _loading = false;
    });
  }

  void _onQueryChanged(String query) {
    final q = query.trim();
    setState(() {
      _results = q.isEmpty
          ? _all
          : _all
              .where((e) =>
                  e.title.toLowerCase().contains(q.toLowerCase()) ||
                  (e.memo?.toLowerCase().contains(q.toLowerCase()) ?? false))
              .toList();
    });
  }

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _formatDate(DateTime d) {
    final w = _weekdays[d.weekday - 1];
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}.$mm.$dd ($w)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '일정 제목, 메모로 검색',
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('검색 결과가 없습니다.'))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = _results[index];
                    return ListTile(
                      title: Text(e.title),
                      subtitle:
                          Text(_formatDate(e.date) + (e.isLunar ? ' · 음력' : '')),
                      trailing: e.notify ? const Icon(Icons.notifications_active, size: 18) : null,
                    );
                  },
                ),
    );
  }
}
