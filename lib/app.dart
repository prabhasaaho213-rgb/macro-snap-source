import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/phone_login_screen.dart';

class MacroSnapApp extends StatefulWidget {
  const MacroSnapApp({super.key});

  @override
  State<MacroSnapApp> createState() => _MacroSnapAppState();
}

class _MacroSnapAppState extends State<MacroSnapApp> {
  bool _loading = true;
  String? _savedPhone;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone');
    if (mounted) setState(() { _savedPhone = phone; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroSnap',
      debugShowCheckedModeBanner: false,
      theme: MacroSnapTheme.light,
      darkTheme: MacroSnapTheme.dark,
      themeMode: ThemeMode.system,
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_savedPhone != null ? const HomeScreen() : const PhoneLoginScreen()),
    );
  }
}
