import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/diet_profile.dart';
import '../services/meal_store.dart';
import '../widgets/glass_card.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  Gender _gender = Gender.male;
  Goal _goal = Goal.loseWeight;
  ActivityLevel _activity = ActivityLevel.sedentary;
  DietProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await DietPlanService.instance.load();
    final p = DietPlanService.instance.profile;
    if (p != null && mounted) {
      setState(() {
        _profile = p;
        _weightCtrl.text = p.weightKg.toStringAsFixed(1);
        _heightCtrl.text = p.heightCm.toStringAsFixed(1);
        _ageCtrl.text = p.age.toString();
        _gender = p.gender;
        _goal = p.goal;
        _activity = p.activity;
      });
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final w = double.tryParse(_weightCtrl.text);
    final h = double.tryParse(_heightCtrl.text);
    final a = int.tryParse(_ageCtrl.text);
    if (w == null || h == null || a == null || w <= 0 || h <= 0 || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Enter valid weight, height & age'), backgroundColor: MacroSnapTheme.rose),
      );
      return;
    }
    final profile = DietProfile(weightKg: w, heightCm: h, age: a, gender: _gender, goal: _goal, activity: _activity);
    DietPlanService.instance.save(profile);
    setState(() => _profile = profile);
  }

  void _reset() {
    DietPlanService.instance.save(DietProfile(weightKg: 70, heightCm: 170, age: 25, gender: Gender.male, goal: Goal.maintain, activity: ActivityLevel.moderate));
    _weightCtrl.text = '70';
    _heightCtrl.text = '170';
    _ageCtrl.text = '25';
    setState(() { _gender = Gender.male; _goal = Goal.maintain; _activity = ActivityLevel.moderate; _profile = null; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Diet Plan'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _reset)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInputSection(isDark),
            if (_profile != null) ...[
              const SizedBox(height: 20),
              _buildTargetsCard(isDark),
              const SizedBox(height: 16),
              _buildProgressCard(isDark),
              const SizedBox(height: 16),
              _buildMealPlan(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(bool isDark) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder(), isDense: true),
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder(), isDense: true),
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder(), isDense: true),
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Gender>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), isDense: true),
            items: const [DropdownMenuItem(value: Gender.male, child: Text('Male')), DropdownMenuItem(value: Gender.female, child: Text('Female'))],
            onChanged: (v) => setState(() => _gender = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Goal>(
            value: _goal,
            decoration: const InputDecoration(labelText: 'Goal', border: OutlineInputBorder(), isDense: true),
            items: Goal.values.map((g) => DropdownMenuItem(value: g, child: Text(DietPlanService.goalLabel(g)))).toList(),
            onChanged: (v) => setState(() => _goal = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ActivityLevel>(
            value: _activity,
            decoration: const InputDecoration(labelText: 'Activity Level', border: OutlineInputBorder(), isDense: true),
            items: ActivityLevel.values.map((a) => DropdownMenuItem(value: a, child: Text(DietPlanService.activityLabel(a)))).toList(),
            onChanged: (v) => setState(() => _activity = v!),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: _calculate,
              style: FilledButton.styleFrom(backgroundColor: MacroSnapTheme.emerald, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Calculate & Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetsCard(bool isDark) {
    final p = _profile!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: MacroSnapTheme.emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(DietPlanService.goalLabel(p.goal), style: const TextStyle(color: MacroSnapTheme.emerald, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('${p.targetCalories} kcal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ]),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _targetItem('Protein', p.targetProtein.toInt(), 'g', MacroSnapTheme.rose, isDark),
              _targetItem('Carbs', p.targetCarbs.toInt(), 'g', MacroSnapTheme.amber, isDark),
              _targetItem('Fats', p.targetFats.toInt(), 'g', MacroSnapTheme.blue, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Text('BMR: ${p.bmr.round()} kcal | TDEE: ${p.tdee.round()} kcal', style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _targetItem(String label, int value, String unit, Color color, bool isDark) {
    return Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
        child: Center(child: Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
      ),
      const SizedBox(height: 4),
      Text('$label ($unit)', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
    ]);
  }

  Widget _buildProgressCard(bool isDark) {
    final p = _profile!;
    final cal = MealStore.instance.todayCalories;
    final protein = MealStore.instance.todayProtein;
    final ratio = (cal / p.targetCalories).clamp(0.0, 1.0);
    final protRatio = (protein / p.targetProtein).clamp(0.0, 1.0);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Progress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _progressRow('Calories', cal, p.targetCalories, ratio, MacroSnapTheme.amber, isDark),
          const SizedBox(height: 12),
          _progressRow('Protein', protein.toInt(), p.targetProtein.toInt(), protRatio, MacroSnapTheme.rose, isDark),
        ],
      ),
    );
  }

  Widget _progressRow(String label, int current, int target, double ratio, Color color, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : const Color(0xFF64748B))),
        Text('$current / $target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation<Color>(color)),
      ),
    ]);
  }

  Widget _buildMealPlan(bool isDark) {
    final p = _profile!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggested Meal Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 16),
          _mealItem(Icons.wb_sunny_rounded, 'Breakfast (~${(p.targetCalories * 0.25).round()} kcal)', _breakfastSuggestion(p), MacroSnapTheme.amber, isDark),
          _mealItem(Icons.free_breakfast_rounded, 'Morning Snack (~${(p.targetCalories * 0.1).round()} kcal)', _snackSuggestion(p), MacroSnapTheme.emerald, isDark),
          _mealItem(Icons.wb_cloudy_rounded, 'Lunch (~${(p.targetCalories * 0.3).round()} kcal)', _lunchSuggestion(p), MacroSnapTheme.blue, isDark),
          _mealItem(Icons.nightlight_round, 'Evening Snack (~${(p.targetCalories * 0.1).round()} kcal)', _snackSuggestion(p), MacroSnapTheme.emerald, isDark),
          _mealItem(Icons.nights_stay_rounded, 'Dinner (~${(p.targetCalories * 0.25).round()} kcal)', _dinnerSuggestion(p), MacroSnapTheme.rose, isDark),
          const SizedBox(height: 16),
          Text('Portion sizes are approximate. Adjust based on your appetite and progress.', style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : const Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _mealItem(IconData icon, String title, String suggestion, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(suggestion, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF94A3B8))),
        ])),
      ]),
    );
  }

  String _breakfastSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return '2 egg whites + 1 multigrain roti + 1 bowl curd + mixed veggies';
    return '2 whole eggs + 2 multigrain roti + 1 bowl sprouts salad + 1 banana';
  }

  String _lunchSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return '1 roti + dal + green veg sabzi + salad + buttermilk';
    if (p.goal == Goal.gainMuscle) return '2 roti + dal + paneer bhurji + rice + curd + salad';
    return '2 roti + dal + seasonal veg + salad + curd';
  }

  String _dinnerSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return 'Grilled chicken/fish + stir-fried veggies + soup';
    if (p.goal == Goal.gainMuscle) return 'Chicken/paneer + rice + veggies + 1 glass milk';
    return 'Light roti/kichdi + veg curry + salad';
  }

  String _snackSuggestion(DietProfile p) {
    if (p.goal == Goal.loseWeight) return '1 apple + 5 almonds or green tea / black coffee';
    if (p.goal == Goal.gainMuscle) return 'Handful dry fruits + 1 glass milk + 1 banana';
    return '1 fruit + buttermilk or handful of roasted chana';
  }
}
