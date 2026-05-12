import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../network/api_client.dart';

/// Edge backend’den cloud bağlantısı (heartbeat) özetini periyodik okur.
class EdgeCloudLinkBanner extends ConsumerStatefulWidget {
  const EdgeCloudLinkBanner({super.key});

  @override
  ConsumerState<EdgeCloudLinkBanner> createState() => _EdgeCloudLinkBannerState();
}

class _EdgeCloudLinkBannerState extends ConsumerState<EdgeCloudLinkBanner> {
  Timer? _timer;
  Map<String, dynamic>? _payload;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pull();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _pull());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pull() async {
    try {
      final res = await ApiClient.instance.get('/edge/system/cloud-link');
      final data = res.data;
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _payload = Map<String, dynamic>.from(data);
          _error = null;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Bağlantı hatası';
        _payload = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _payload = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Material(
        color: Colors.red.shade800,
        child: InkWell(
          onTap: _pull,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edge sunucusuna ulaşılamıyor ($_error) — dokunarak yenile',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final p = _payload;
    if (p == null) {
      return Material(
        color: Colors.blueGrey.shade700,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 10),
              Text(
                'Cloud bağlantısı kontrol ediliyor…',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final tryLive = p['tryCloudLive'] == true;
    final reachable = p['cloudHeartbeatReachable'] == true;
    final lastOkStr = (p['lastHeartbeatSuccessAt'] as String?)?.trim() ?? '';
    DateTime? lastOk;
    if (lastOkStr.isNotEmpty) {
      lastOk = DateTime.tryParse(lastOkStr);
    }
    final lastFmt = lastOk != null
        ? DateFormat('dd.MM.yyyy HH:mm:ss', 'tr_TR').format(lastOk.toLocal())
        : null;
    final lag = (p['syncLagSeconds'] as num?)?.toInt() ?? 0;

    Color bg;
    IconData icon;
    String title;
    String subtitle;

    if (!tryLive) {
      bg = Colors.amber.shade800;
      icon = Icons.link_off;
      title = 'Cloud köprüsü yapılandırılmamış';
      subtitle = 'Köprü JWT veya lab eşlemesi gerekir';
    } else if (reachable) {
      bg = Colors.green.shade800;
      icon = Icons.cloud_done;
      title = 'Cloud’a bağlı (heartbeat aktif)';
      subtitle = lastFmt != null ? 'Son başarılı sinyal: $lastFmt' : 'Sinyal alındı';
      if (lag > 30) {
        subtitle += ' · outbox gecikmesi ~${lag}s';
      }
    } else {
      bg = Colors.deepOrange.shade900;
      icon = Icons.cloud_off;
      title = 'Cloud’a ulaşım sorunu veya sinyal kesildi';
      final err = (p['lastHeartbeatError'] as String?)?.trim();
      subtitle = lastFmt != null
          ? 'Son başarılı: $lastFmt'
          : 'Henüz başarılı heartbeat yok';
      if (err != null && err.isNotEmpty && err != 'unknown') {
        subtitle += ' · $err';
      }
    }

    return Material(
      color: bg,
      child: InkWell(
        onTap: _pull,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
