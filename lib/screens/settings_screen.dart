import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import 'subscription_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = 'User';
  String _email = '';
  bool _subscribed = false;
  String? _subscribedDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('name') ?? 'User';
      _email = prefs.getString('email') ?? '';
      _subscribed = prefs.getBool('subscribed') ?? false;
      _subscribedDate = prefs.getString('subscribed_at');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                    child: Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    if (_email.isNotEmpty) Text(_email, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                  ])),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_subscribed ? 'Pro Member' : 'Free User',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(children: [
                _settingTile(Icons.subscriptions_rounded, _subscribed ? 'Manage Subscription' : 'Upgrade to Pro', _subscribed && _subscribedDate != null ? 'Subscribed since ${_subscribedDate!.substring(0, 10)}' : 'Unlock AI meal plans & more', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                }, isDark),
                const Divider(height: 24),
                _settingTile(Icons.info_outline_rounded, 'App Version', '1.2.1', null, isDark),
                const Divider(height: 24),
                _settingTile(Icons.mail_outline_rounded, 'Contact Support', 'macro.snap@email.com', () async {
                  // No-op, just display
                }, isDark),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Made with ❤️ in India', style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(IconData icon, String title, String subtitle, VoidCallback? onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: MacroSnapTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: MacroSnapTheme.emerald, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
        ])),
        if (onTap != null) Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1), size: 20),
      ]),
    );
  }
}
