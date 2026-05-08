import 'dart:async';

import 'package:flutter/material.dart';

import '../network/api_client.dart';

class SyncLagIndicator extends StatefulWidget {
  const SyncLagIndicator({super.key});

  @override
  State<SyncLagIndicator> createState() => _SyncLagIndicatorState();
}

class _SyncLagIndicatorState extends State<SyncLagIndicator> {
  Timer? _timer;
  bool _loading = true;
  int _lagSeconds = 0;
  String _level = 'UNKNOWN';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final response = await ApiClient.instance.get('/edge/system/sync-status');
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      setState(() {
        _lagSeconds = (data['syncLagSeconds'] as num?)?.toInt() ?? 0;
        _level = (data['level'] as String?) ?? 'UNKNOWN';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _level = 'UNKNOWN';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _colorByLevel(String level) {
    return switch (level) {
      'OK' => Colors.green,
      'DELAYED' => Colors.orange,
      'CRITICAL' => Colors.red,
      _ => Colors.blueGrey,
    };
  }

  String _label() {
    if (_loading) return 'Sync: ...';
    if (_level == 'UNKNOWN') return 'Sync: N/A';
    return 'Sync: ${_lagSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorByLevel(_level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.sync, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            _label(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
