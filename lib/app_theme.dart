import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppColors — paleta centralizada de colores de CaloFit
//
// Uso: AppColors.primary  en vez de  const Color(0xFF1E88E5)
//
// Si se necesita cambiar el azul corporativo, solo se cambia aquí.
// ─────────────────────────────────────────────────────────────────────────────
abstract class AppColors {
  // ── Azul corporativo (botones primarios, headers, progress bars) ──────────
  static const Color primary     = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);

  // ── Fondos ────────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF1F5F9); // fondo gris claro de pantallas

  // ── Texto ─────────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF1E293B); // títulos y nombres en cards

  // ── Macros nutricionales (chips, etiquetas, barras de progreso) ───────────
  static const Color macroProtein = Color(0xFFEF5350); // proteínas — rojo
  static const Color macroCarbs   = Color(0xFFFFA726); // carbohidratos — naranja
  static const Color macroFat     = Color(0xFF42A5F5); // grasas — azul claro
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextStyles — estilos de texto reutilizables
//
// Uso: style: AppTextStyles.cardTitle
// ─────────────────────────────────────────────────────────────────────────────
abstract class AppTextStyles {
  // Nombres de alimentos/ejercicios en cards de lista
  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  // Etiqueta pequeña (label de chip, tab, badge)
  static const TextStyle chipLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );

  // Números grandes en el header (kcal restantes, porcentaje)
  static const TextStyle heroNumber = TextStyle(
    color: Colors.white,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -1,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme — ThemeData listo para usar en MaterialApp
// ─────────────────────────────────────────────────────────────────────────────
abstract class AppTheme {
  static ThemeData get light => ThemeData(
        primaryColor: AppColors.primary,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      );
}
