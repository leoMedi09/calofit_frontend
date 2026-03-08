import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class UrlService {
  /// Formatea una URL del backend para que sea accesible desde el emulador o dispositivo real.
  /// Reemplaza 'localhost' por la IP del host del emulador (10.0.2.2) si es necesario.
  static String formatImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    debugPrint('🖼️ UrlService: Input URL = $url');
    
    // Obtener la base URL configurada
    String baseUrl = ApiConfig.baseUrl;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    // Parse baseUrl to get current valid host/port
    Uri baseUri = Uri.parse(baseUrl);

    // 🛡️ PROTECCIÓN DE IP/HOST EXTREMA:
    // Si la URL es absoluta y parece ser de nuestro backend (contiene port 8000 o /uploads/),
    // forzamos el host y puerto para que coincidan con la configuración actual (baseUrl).
    // Esto previene que IPs antiguas o unreachable (.72) causen Timeouts (.78 o 10.0.2.2).
    if (url.startsWith('http')) {
      // 🛡️ EXCEPCIÓN: Si ya es una URL de nube (Cloudinary o Firebase), NO la tocamos.
      if (url.contains('cloudinary.com') || url.contains('storage.googleapis.com')) {
        debugPrint('☁️ UrlService: Cloud URL detected, skipping patch.');
        return url;
      }

      bool isBackendUrl = url.contains(':8000') || url.contains('/uploads/') || url.contains('/profiles/');
      
      if (isBackendUrl) {
        try {
          Uri imageUri = Uri.parse(url);
          // Forzamos reemplazo siempre que el host/puerto sea sospechoso o diferente
          String patched = imageUri.replace(
            scheme: baseUri.scheme,
            host: baseUri.host,
            port: baseUri.port,
          ).toString();
          debugPrint('🛡️ UrlService: Patched URL = $patched');
          return patched;
        } catch (e) {
          debugPrint('❌ UrlService: Error patching URL: $e');
          return url;
        }
      }
    }

    // Si la URL es relativa
    if (!url.startsWith('http')) {
      String relativePath = url;
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.substring(1);
      }
      return '$baseUrl/$relativePath';
    }

    // Caso especial para localhost/127.0.0.1 (fallback extra)
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      Uri imageUri = Uri.parse(url);
      return imageUri.replace(
        scheme: baseUri.scheme,
        host: baseUri.host,
        port: baseUri.port,
      ).toString();
    }

    return url;
  }
}
