String resolveApiBaseUrlImpl(String baseUrl) {
  // Mixed-content problemini tamamen önlemek için web'de baseUrl'yi asla
  // "http://host/..." gibi mutlak URL olarak kullanmıyoruz.
  // Bunun yerine sadece path döndürüp istemleri aynı origin'e göreli yapıyoruz:
  //   - API_URL=http://165.245.214.173/api  ->  '/api'
  //   - API_URL=/api                         ->  '/api'
  if (baseUrl.startsWith('/')) return baseUrl;

  final uri = Uri.tryParse(baseUrl);
  final path = (uri != null && uri.path.isNotEmpty) ? uri.path : '/api';
  return path.startsWith('/') ? path : '/$path';
}

