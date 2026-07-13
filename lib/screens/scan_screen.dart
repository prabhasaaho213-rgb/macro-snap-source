import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../services/scan_gate.dart';
import 'result_screen.dart';
import 'subscription_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  int _scansLeft = 3;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadScans();
  }

  Future<void> _loadScans() async {
    final remaining = await ScanGate.getScansRemaining();
    if (mounted) setState(() => _scansLeft = remaining);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!await ScanGate.canScan()) {
      if (mounted) _showLimitDialog();
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 512, imageQuality: 70);
    if (image != null && mounted) {
      await ScanGate.incrementScan();
      final bytes = await image.readAsBytes();
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/food_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(imagePath: tempFile.path),
          ),
        );
      }
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MacroSnapTheme.amber.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.flash_on_rounded,
                  color: MacroSnapTheme.amber, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Free scans used up',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('You get 3 free AI scans per month.\nGo Pro for unlimited scans.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: Colors.grey.shade500, height: 1.4)),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Go Pro - \u20B929/mo',
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
              height: 48,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Maybe later',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canUse = _scansLeft > 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Snap & Track'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + (_pulseController.value * 0.05),
                    child: child,
                  );
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt_rounded, size: 64, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Snap a photo of your meal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Our AI will analyze your food and provide\ninstant nutrition details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _scansLeft >= 99
                      ? 'Unlimited scans'
                      : '$_scansLeft scan${_scansLeft == 1 ? '' : 's'} remaining this month',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose,
                  ),
                ),
              ),
              const Spacer(),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose method',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ScanOption(
                      icon: Icons.camera_alt_rounded,
                      title: 'Take a Photo',
                      subtitle: 'Capture your meal right now',
                      gradient: const LinearGradient(
                        colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                      ),
                      onTap: () => _pickImage(ImageSource.camera),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _ScanOption(
                      icon: Icons.photo_library_rounded,
                      title: 'Choose from Gallery',
                      subtitle: 'Select an existing photo',
                      gradient: const LinearGradient(
                        colors: [MacroSnapTheme.amber, Color(0xFFFBBF24)],
                      ),
                      onTap: () => _pickImage(ImageSource.gallery),
                      isDark: isDark,
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

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool isDark;

  const _ScanOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              gradient.colors.first.withValues(alpha: 0.1),
              gradient.colors.last.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(
            color: gradient.colors.first.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
