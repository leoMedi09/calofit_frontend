import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Configuración centralizada de URLs por plataforma

  // Cambia a false para usar el backend local (desarrollo)
  static const bool useProduction = false;

  static String get baseUrl {
    if (useProduction) {
      return prodUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'http://192.168.15.195:8000'; // IP local Wi-Fi
    } else if (Platform.isIOS) {
      return 'http://localhost:8000';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'http://localhost:8000';
    }
    return devUrl;
  }

  // URLs alternativas para diferentes entornos
  static const String devUrl = 'http://localhost:8000'; // desarrollo local
  static const String prodUrl =
      'https://calofit-backend.onrender.com'; // producción Render

  // Para dispositivos físicos Android, usa la IP de tu máquina

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Función de ayuda para debugging
  static void printCurrentConfig() {
    if (kDebugMode) {
      print('API Base URL: $baseUrl');
      print('Platform: ${_getPlatformName()}');
    }
  }

  static String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
