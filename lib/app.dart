import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

class MacroSnapApp extends StatelessWidget {
  const MacroSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MacroSnap',
      debugShowCheckedModeBanner: false,
      theme: MacroSnapTheme.light,
      darkTheme: MacroSnapTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
