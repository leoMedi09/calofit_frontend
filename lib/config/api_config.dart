import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const bool useProduction = true;

  static String get baseUrl {
    if (useProduction) {
      return prodUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'http://192.168.15.195:8000';
    } else if (Platform.isIOS) {
      return 'http://localhost:8000';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'http://localhost:8000';
    }
    return devUrl;
  }

  static const String devUrl = 'http://localhost:8000';
  static const String prodUrl = 'https://calofit-backend.onrender.com';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

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
