import 'package:flutter/foundation.dart';

/// Uygulama genelinde oturum düşmesi (401) olayını tek merkezden yayınlar.
/// Amaç: 401 geldiğinde tek sefer logout/yönlendirme yapmak.
class AuthSessionEvents {
  AuthSessionEvents._();

  static final ValueNotifier<int> unauthorizedSignal = ValueNotifier<int>(0);
  static bool _cooldown = false;

  static void notifyUnauthorized() {
    if (_cooldown) return;
    _cooldown = true;
    unauthorizedSignal.value = unauthorizedSignal.value + 1;

    // Arka arkaya gelen birden çok 401 için debounce.
    Future<void>.delayed(const Duration(seconds: 2), () {
      _cooldown = false;
    });
  }
}

