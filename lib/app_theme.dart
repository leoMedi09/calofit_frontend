import 'package:flutter/material.dart';

abstract class AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);

  static const Color surface = Color(0xFFF1F5F9);

  static const Color textDark = Color(0xFF1E293B);

  static const Color macroProtein = Color(0xFFEF5350);
  static const Color macroCarbs = Color(0xFFFFA726);
  static const Color macroFat = Color(0xFF42A5F5);
}

abstract class AppTextStyles {
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static const TextStyle chipLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle heroNumber = TextStyle(
    color: Colors.white,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -1,
  );
}

abstract class AppTheme {
  static ThemeData get light => ThemeData(
        primaryColor: AppColors.primary,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      );
}
