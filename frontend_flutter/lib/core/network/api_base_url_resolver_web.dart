// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

String resolveApiBaseUrlImpl(String baseUrl) {
  final protocol = html.window.location.protocol; // 'https:' / 'http:'
  if (protocol != 'https:') return baseUrl;

  final origin = html.window.location.origin; // 'https://quickserve.duckdns.org'

  // baseUrl her zaman mutlak bir URL olmasa da (ör. '/api'), bunu tolere ediyoruz.
  if (baseUrl.startsWith('/')) {
    return '$origin$baseUrl';
  }

  final uri = Uri.tryParse(baseUrl);
  if (uri == null) return baseUrl;

  final path = uri.path.isNotEmpty ? uri.path : '/api';
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return '$origin$normalizedPath';
}

