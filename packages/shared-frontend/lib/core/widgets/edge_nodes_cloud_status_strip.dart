import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

bool edgeNodeEffectiveOnline(dynamic node) {
  if (node is! Map) return false;
  final e = node['effectiveOnline'];
  if (e == true) return true;
  if (e == false) return false;
  return node['status'] == 'ONLINE';
}

DateTime? parseApiLocalDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
  if (raw is List && raw.length >= 5) {
    return DateTime(
      (raw[0] as num).toInt(),
      (raw[1] as num).toInt(),
      (raw[2] as num).toInt(),
      raw.length > 3 ? (raw[3] as num).toInt() : 0,
      raw.length > 4 ? (raw[4] as num).toInt() : 0,
      raw.length > 5 ? (raw[5] as num).toInt() : 0,
    );
  }
  return null;
}

DateTime? maxLastSeenAt(Iterable<dynamic> nodes) {
  DateTime? best;
  for (final n in nodes) {
    if (n is! Map) continue;
    final d = parseApiLocalDateTime(n['lastSeenAt']);
    if (d != null && (best == null || d.isAfter(best))) {
      best = d;
    }
  }
  return best;
}

/// Cloud tarafında: edge node’ların cloud’a son sinyal durumu (heartbeat).
class EdgeNodesCloudStatusStrip extends StatelessWidget {
  final List<dynamic> nodes;
  final bool compact;

  const EdgeNodesCloudStatusStrip({
    super.key,
    required this.nodes,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return _wrap(
        compact,
        Icons.cloud_off_outlined,
        Colors.blueGrey,
        'Cloud ↔ Edge: kayıtlı edge kutusu yok',
      );
    }
    final anyOnline = nodes.any((n) => edgeNodeEffectiveOnline(n));
    final last = maxLastSeenAt(nodes);
    final ts = last != null
        ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(last.toLocal())
        : null;
    final detail = ts != null ? 'Son görülme: $ts' : 'Son sinyal yok';
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(
              anyOnline ? Icons.cloud_done : Icons.cloud_off,
              size: 15,
              color: anyOnline ? Colors.green.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                anyOnline ? 'Edge çevrim içi · $detail' : 'Edge çevrim dışı · $detail',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: anyOnline ? Colors.green.shade800 : Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: anyOnline ? Colors.green.shade50 : Colors.orange.shade50,
      child: Row(
        children: [
          Icon(
            anyOnline ? Icons.hub : Icons.hub_outlined,
            size: 18,
            color: anyOnline ? Colors.green.shade800 : Colors.orange.shade900,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anyOnline
                      ? 'Edge kutusu cloud ile çevrim içi'
                      : 'Edge kutusu cloud ile çevrim dışı',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: anyOnline ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrap(bool isCompact, IconData icon, Color color, String text) {
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blueGrey.shade50,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
