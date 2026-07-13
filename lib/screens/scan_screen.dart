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
  late AnimationController _scanLineController;

  int _scansLeft = 3;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _loadScans();
  }

  Future<void> _loadScans() async {
    final remaining = await ScanGate.getScansRemaining();
    if (mounted) setState(() => _scansLeft = remaining);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
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
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Snap & Track',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flash_on_rounded, size: 14,
                    color: canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose),
                const SizedBox(width: 4),
                Text(
                  _scansLeft >= 99 ? 'Unlimited' : '$_scansLeft left',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: canUse ? MacroSnapTheme.emerald : MacroSnapTheme.rose,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Viewfinder area
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: MacroSnapTheme.emerald.withValues(alpha: 0.15 + (_pulseController.value * 0.1)),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: MacroSnapTheme.emerald.withValues(alpha: 0.06 + (_pulseController.value * 0.06)),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Viewfinder frame
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Corner accents
                                CornerAccent(position: CornerPosition.topLeft, animation: _pulseController),
                                CornerAccent(position: CornerPosition.topRight, animation: _pulseController),
                                CornerAccent(position: CornerPosition.bottomLeft, animation: _pulseController),
                                CornerAccent(position: CornerPosition.bottomRight, animation: _pulseController),
                                // Center icon
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: MacroSnapTheme.emerald.withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 32,
                                          color: MacroSnapTheme.emerald,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Snap your meal',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.7),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Scanning line animation
                                AnimatedBuilder(
                                  animation: _scanLineController,
                                  builder: (context, _) {
                                    return Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 20 + (_scanLineController.value * 200),
                                      child: Container(
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              MacroSnapTheme.emerald.withValues(alpha: 0.6),
                                              Colors.transparent,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Instruction text below viewfinder
                          Positioned(
                            bottom: -40,
                            child: Text(
                              'Position your food in the frame',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    isDark ? const Color(0xFF0A0E1A) : const Color(0xFF0F172A),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Gallery button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_rounded,
                                color: Colors.white.withValues(alpha: 0.7), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Main camera button
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MacroSnapTheme.emerald.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Spacer for symmetry
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum CornerPosition { topLeft, topRight, bottomLeft, bottomRight }

class CornerAccent extends StatelessWidget {
  final CornerPosition position;
  final Animation<double> animation;
  const CornerAccent({super.key, required this.position, required this.animation});

  @override
  Widget build(BuildContext context) {
    final align = switch (position) {
      CornerPosition.topLeft => Alignment.topLeft,
      CornerPosition.topRight => Alignment.topRight,
      CornerPosition.bottomLeft => Alignment.bottomLeft,
      CornerPosition.bottomRight => Alignment.bottomRight,
    };
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => Align(
        alignment: align,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: MacroSnapTheme.emerald.withValues(alpha: 0.3 + (animation.value * 0.2)),
            borderRadius: switch (position) {
              CornerPosition.topLeft => const BorderRadius.only(topLeft: Radius.circular(24)),
              CornerPosition.topRight => const BorderRadius.only(topRight: Radius.circular(24)),
              CornerPosition.bottomLeft => const BorderRadius.only(bottomLeft: Radius.circular(24)),
              CornerPosition.bottomRight => const BorderRadius.only(bottomRight: Radius.circular(24)),
            },
          ),
        ),
      ),
    );
  }
}
