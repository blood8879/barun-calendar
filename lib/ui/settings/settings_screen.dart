import 'package:flutter/material.dart';

import '../../data/event/event_repository.dart';
import '../../data/settings/settings_repository.dart';
import '../backup/backup_restore_screen.dart';
import '../import/import_screen.dart';
import '../paywall/paywall_screen.dart';

/// 디자인 목업 S8 대응 설정 화면.
class SettingsScreen extends StatefulWidget {
  final SettingsRepository settingsRepository;
  final EventRepository eventRepository;
  final ValueChanged<AppSettings> onSettingsChanged;
  final VoidCallback? onReplayOnboarding;

  const SettingsScreen({
    super.key,
    required this.settingsRepository,
    required this.eventRepository,
    required this.onSettingsChanged,
    this.onReplayOnboarding,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.settingsRepository.load();
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _update(AppSettings next) async {
    setState(() => _settings = next);
    await widget.settingsRepository.save(next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionHeader('화면'),
          SwitchListTile(
            title: const Text('다크 모드'),
            value: _settings.darkMode,
            onChanged: (v) => _update(_settings.copyWith(darkMode: v)),
          ),
          ListTile(
            title: const Text('글자 크기'),
            subtitle: Slider(
              value: _settings.fontScale,
              min: 0.85,
              max: 1.5,
              divisions: 13,
              label: '${(_settings.fontScale * 100).round()}%',
              onChanged: (v) => _update(_settings.copyWith(fontScale: v)),
            ),
          ),
          const Divider(),
          const _SectionHeader('표시 항목'),
          SwitchListTile(
            title: const Text('일진 표시'),
            value: _settings.showGanji,
            onChanged: (v) => _update(_settings.copyWith(showGanji: v)),
          ),
          SwitchListTile(
            title: const Text('음력 표시'),
            value: _settings.showLunar,
            onChanged: (v) => _update(_settings.copyWith(showLunar: v)),
          ),
          SwitchListTile(
            title: const Text('절기 표시'),
            value: _settings.showSolarTerm,
            onChanged: (v) => _update(_settings.copyWith(showSolarTerm: v)),
          ),
          SwitchListTile(
            title: const Text('공휴일 표시'),
            value: _settings.showHoliday,
            onChanged: (v) => _update(_settings.copyWith(showHoliday: v)),
          ),
          SwitchListTile(
            title: const Text('손없는날 표시'),
            subtitle: const Text('음력 날짜 끝자리가 9 또는 0인 날(이사·개업 등에 좋다는 민간 택일)'),
            value: _settings.showSonEobsneun,
            onChanged: (v) => _update(_settings.copyWith(showSonEobsneun: v)),
          ),
          const Divider(),
          const _SectionHeader('데이터'),
          ListTile(
            title: const Text('백업 / 복원'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BackupRestoreScreen(
                  eventRepository: widget.eventRepository,
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('가져오기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImportScreen(eventRepository: widget.eventRepository),
              ),
            ),
          ),
          const Divider(),
          const _SectionHeader('평생권'),
          ListTile(
            title: const Text('광고 제거 · 평생권 구매'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            ),
          ),
          const Divider(),
          const _SectionHeader('도움말'),
          ListTile(
            title: const Text('사용법 다시 보기'),
            subtitle: const Text('홈 화면 주요 기능을 안내하는 화면을 다시 표시합니다'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onReplayOnboarding == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onReplayOnboarding!();
                  },
          ),
          const Divider(),
          const _SectionHeader('앱 정보'),
          const ListTile(title: Text('바른달력'), subtitle: Text('버전 1.0.0')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
