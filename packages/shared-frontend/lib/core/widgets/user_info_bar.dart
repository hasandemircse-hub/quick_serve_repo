import 'package:flutter/material.dart';
import '../storage/local_storage.dart';

/// AppBar'da kullanıcı bilgisi + çıkış butonu gösterir.
/// Herhangi bir ekranın AppBar.actions listesine eklenebilir.
class UserInfoBar extends StatefulWidget {
  final VoidCallback onLogout;

  const UserInfoBar({super.key, required this.onLogout});

  @override
  State<UserInfoBar> createState() => _UserInfoBarState();
}

class _UserInfoBarState extends State<UserInfoBar> {
  String _displayName = '';
  String _roleLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await LocalStorage.getUserInfo();
    if (!mounted) return;
    final fullName = info['fullName'] as String?;
    final username = info['username'] as String? ?? '';
    final role = info['role'] as String? ?? '';
    setState(() {
      _displayName = (fullName != null && fullName.isNotEmpty) ? fullName : username;
      _roleLabel = _toRoleLabel(role);
    });
  }

  String _toRoleLabel(String role) => switch (role) {
        'SUPERADMIN' => 'Superadmin',
        'RESTAURANT_ADMIN' => 'Restoran Admin',
        'HEAD_WAITER' => 'Baş Garson',
        'WAITER' => 'Garson',
        'CHEF' => 'Aşçı',
        'VALET' => 'Vale',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    if (_displayName.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.logout),
        tooltip: 'Çıkış Yap',
        onPressed: widget.onLogout,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _displayName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                _roleLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Çıkış Yap',
          onPressed: widget.onLogout,
        ),
      ],
    );
  }
}
