import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/meal_store.dart';
import '../services/update_checker.dart';
import '../models/diet_profile.dart';
import 'diet_plan_screen.dart';
import '../widgets/glass_card.dart';
import '../widgets/macro_ring.dart';
import 'package:macro_snap/services/food_database.dart';
import 'add_meal_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String _avatar = '😎';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    MealStore.instance.load().then((_) {
      if (mounted) _animController.forward();
    });
    DietPlanService.instance.load().then((_) {
      final p = DietPlanService.instance.profile;
      if (p != null && mounted) setState(() => _avatar = p.avatar);
    });
    UpdateChecker.checkAndPrompt(context);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, isDark)),
              SliverToBoxAdapter(child: _buildCalorieCard(context, isDark)),
              SliverToBoxAdapter(child: _buildMacrosSection(context, isDark)),
              SliverToBoxAdapter(child: _buildQuickActions(context, isDark)),
              SliverToBoxAdapter(child: _buildRecentMeals(context, isDark)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello,',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to track?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.settings_rounded, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPlanScreen())).then((_) {
                  final p = DietPlanService.instance.profile;
                  if (p != null) setState(() => _avatar = p.avatar);
                }),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MacroSnapTheme.emerald.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(child: Text(_avatar, style: const TextStyle(fontSize: 22))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GlassCard(
        height: 180,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MacroSnapTheme.emerald.withValues(alpha: isDark ? 0.05 : 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded,
                          color: MacroSnapTheme.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Calories',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        MealStore.instance.todayCalories > 0
                            ? '${MealStore.instance.todayCalories}'
                            : '0',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '/ 2,000 kcal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (MealStore.instance.todayCalories / 2000).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(MacroSnapTheme.emerald),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Macronutrients',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MacroRing(
                  progress: (MealStore.instance.todayProtein / 150).clamp(0.0, 1.0) as double,
                  value: MealStore.instance.todayProtein,
                  target: 150,
                  label: 'Protein',
                  color: MacroSnapTheme.rose,
                ),
                MacroRing(
                  progress: (MealStore.instance.todayCarbs / 300).clamp(0.0, 1.0) as double,
                  value: MealStore.instance.todayCarbs,
                  target: 300,
                  label: 'Carbs',
                  color: MacroSnapTheme.amber,
                ),
                MacroRing(
                  progress: (MealStore.instance.todayFats / 67).clamp(0.0, 1.0) as double,
                  value: MealStore.instance.todayFats,
                  target: 67,
                  label: 'Fats',
                  color: MacroSnapTheme.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Snap & Track',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const ScanScreen(),
                          transitionsBuilder: (_, a, __, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.search_rounded,
                    label: 'Search Food',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.amber, Color(0xFFFBBF24)],
                    ),
                    onTap: () async {
                      final item = await Navigator.push<FoodItem>(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                      if (item != null && context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddMealScreen(food: item),
                          ),
                        );
                      }
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Diet Plan',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.emerald, MacroSnapTheme.emeraldLight],
                    ),
                    onTap: () async {
                      await DietPlanService.instance.load();
                      if (mounted) {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const DietPlanScreen()));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.history_rounded,
                    label: 'History',
                    gradient: const LinearGradient(
                      colors: [MacroSnapTheme.amber, Color(0xFFFBBF24)],
                    ),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentMeals(BuildContext context, bool isDark) {
    final meals = MealStore.instance.todayMeals;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Meals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            if (meals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No meals logged yet.\nSnap a photo or search food!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                  ),
                ),
              )
            else
              ...meals.take(10).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MacroSnapTheme.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: MacroSnapTheme.emerald, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            '${m.category.isNotEmpty ? '${m.category} · ' : ''}${m.serving}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${m.calories} kcal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
