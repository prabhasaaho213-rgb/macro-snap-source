import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/meal_store.dart';
import 'models/diet_profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await MealStore.instance.load();
  await DietPlanService.instance.load();
  runApp(const MacroSnapApp());
}
