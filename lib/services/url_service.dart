import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class UrlService {
  static String formatImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    debugPrint('🖼️ UrlService: Input URL = $url');
    
    String baseUrl = ApiConfig.baseUrl;
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    
    Uri baseUri = Uri.parse(baseUrl);

    if (url.startsWith('http')) {
      if (url.contains('cloudinary.com') || url.contains('storage.googleapis.com')) {
        debugPrint('☁️ UrlService: Cloud URL detected, skipping patch.');
        return url;
      }

      bool isBackendUrl = url.contains(':8000') || url.contains('/uploads/') || url.contains('/profiles/');
      
      if (isBackendUrl) {
        try {
          Uri imageUri = Uri.parse(url);
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

    if (!url.startsWith('http')) {
      String relativePath = url;
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.substring(1);
      }
      return '$baseUrl/$relativePath';
    }

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
