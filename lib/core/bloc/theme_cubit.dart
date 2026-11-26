import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.light) {
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final isLight = prefs.getBool("isLightMode");

    if (isLight != null) {
      emit(isLight ? ThemeMode.light : ThemeMode.dark);
    }
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (state == ThemeMode.light) {
      await prefs.setBool("isLightMode", false);
      emit(ThemeMode.dark);
    } else {
      await prefs.setBool("isLightMode", true);
      emit(ThemeMode.light);
    }
  }
}
