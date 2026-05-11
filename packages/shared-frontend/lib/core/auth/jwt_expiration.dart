import 'dart:convert';

/// JWT payload içindeki `exp` (saniye, UTC). İmza doğrulanmaz; yalnızca süre kontrolü için.
DateTime? readJwtExpirationUtc(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1];
    switch (payload.length % 4) {
      case 1:
        payload = '$payload===';
        break;
      case 2:
        payload = '$payload==';
        break;
      case 3:
        payload = '$payload=';
        break;
      default:
        break;
    }
    final json = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(json) as Map<String, dynamic>;
    final exp = map['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool isJwtStillValid(String token, {DateTime? now}) {
  final exp = readJwtExpirationUtc(token);
  if (exp == null) return false;
  final n = now ?? DateTime.now().toUtc();
  return exp.isAfter(n);
}
