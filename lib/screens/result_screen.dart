import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../models/meal_record.dart';
import '../services/gemini_service.dart';
import '../services/meal_store.dart';
import '../widgets/glass_card.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isAnalyzing = true;
  String? _error;
  NutritionResult? _result;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _analyze();
  }

  Future<void> _analyze() async {
    if (!GeminiService.hasServerUrl) {
      if (mounted) {
        setState(() { _error = 'no_url'; _isAnalyzing = false; });
        _animController.forward();
      }
      return;
    }

    try {
      final result = await GeminiService.analyzeFoodImage(widget.imagePath);
      if (mounted) {
        final grams = await _promptGrams();
        if (grams != null) {
          setState(() { _result = result.withGrams(grams); _isAnalyzing = false; });
          _animController.forward();
        } else {
          setState(() { _result = result; _isAnalyzing = false; });
          _animController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isAnalyzing = false; });
        _animController.forward();
      }
    }
  }

  Future<int?> _promptGrams() async {
    final controller = TextEditingController(text: '250');
    final grams = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Portion Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many grams is this meal?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Grams',
                suffixText: 'g',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              Navigator.pop(ctx, val != null && val > 0 ? val : null);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return grams;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white : const Color(0xFF1E293B), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isAnalyzing ? 'Analyzing...' : _error != null ? 'Error' : 'Results',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
      body: SafeArea(
        child: _isAnalyzing
            ? _buildLoadingState(isDark)
            : _error != null
                ? _buildError(isDark)
                : _buildResults(isDark),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: MacroSnapTheme.emerald,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your meal...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Our AI is identifying ingredients\nand calculating nutrition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    final isNoUrl = _error == 'no_url';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isNoUrl ? MacroSnapTheme.amber : MacroSnapTheme.rose).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isNoUrl ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                color: isNoUrl ? MacroSnapTheme.amber : MacroSnapTheme.rose,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isNoUrl ? 'Server Not Set' : 'Analysis Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  isNoUrl
                      ? 'Enter your server URL in Settings\nto enable AI food analysis.'
                      : _error ?? 'Something went wrong.\nPlease try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isNoUrl)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.pop(context),
                      child: const Center(
                        child: Text(
                          'Go to Settings',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final r = _result!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                File(widget.imagePath),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      _buildMealHeader(isDark, r),
                      const Divider(height: 32),
                      _buildTotalCalories(isDark, r),
                      const SizedBox(height: 24),
                      _buildMacroRow(isDark, r),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _animController,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
                  )),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrition Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNutrientRow('Calories', r.calories, 'kcal', MacroSnapTheme.amber, isDark),
                        _buildNutrientRow('Protein', r.protein, 'g', MacroSnapTheme.rose, isDark),
                        _buildNutrientRow('Carbs', r.carbs, 'g', MacroSnapTheme.amber, isDark),
                        _buildNutrientRow('Fats', r.fats, 'g', MacroSnapTheme.blue, isDark),
                        _buildNutrientRow('Fiber', r.fiber, 'g', MacroSnapTheme.emerald, isDark),
                      ],
                    ),
                  ),
                ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _animController,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                    )),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: MacroSnapTheme.emerald.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: MacroSnapTheme.emerald, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Confidence',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${(r.confidence * 100).round()}% · ${r.description}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          MealStore.instance.add(MealRecord(
                            id: const Uuid().v4(),
                            date: DateTime.now(),
                            name: r.mealName,
                            category: '',
                            calories: r.calories,
                            protein: r.protein,
                            carbs: r.carbs,
                            fats: r.fats,
                            fiber: r.fiber,
                            serving: r.description,
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Meal logged!'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: const Center(
                          child: Text(
                            'Log This Meal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealHeader(bool isDark, NutritionResult r) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: MacroSnapTheme.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            r.mealName,
            style: const TextStyle(
              color: MacroSnapTheme.emerald,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCalories(bool isDark, NutritionResult r) {
    return Column(
      children: [
        Text(
          '${r.calories}',
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -2,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'kilocalories',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroRow(bool isDark, NutritionResult r) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMacroItem('Protein', '${r.protein.toInt()}g', MacroSnapTheme.rose, isDark),
        _buildMacroItem('Carbs', '${r.carbs.toInt()}g', MacroSnapTheme.amber, isDark),
        _buildMacroItem('Fats', '${r.fats.toInt()}g', MacroSnapTheme.blue, isDark),
      ],
    );
  }

  Widget _buildMacroItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientRow(String label, num value, String unit, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(value is int ? 0 : 1)} $unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
