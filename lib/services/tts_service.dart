import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lectura en voz alta de las respuestas del asistente.
/// - Elige la mejor voz en español del teléfono (o la que el usuario eligió) y prefiere el motor de Google.
/// - Normaliza el texto para que se lea como se habla ("3x10" → "3 series de 10").
/// - Lee frase por frase con pausas cortas y se puede detener en cualquier momento.
class TtsService {
  static const _kNombre = 'tts_voz_nombre';
  static const _kLocale = 'tts_voz_locale';
  static const _motorGoogle = 'com.google.android.tts';

  final FlutterTts _tts = FlutterTts();
  int _sesion = 0;
  Map<String, String>? _vozActual;

  Map<String, String>? get vozActual => _vozActual;

  Future<void> init() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.5); // en Android 0.5 = velocidad normal
      await _tts.setPitch(1.0);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final motores = await _tts.getEngines;
        if (motores is List && motores.contains(_motorGoogle)) await _tts.setEngine(_motorGoogle);
      }
      await _tts.setLanguage('es-MX');
      await _aplicarVozGuardadaOMejor();
    } catch (e) {
      debugPrint('TTS init: $e'); // la lectura sigue funcionando con la voz por defecto
    }
  }

  // ---------------------------------------------------------------- voces
  Future<List<Map<String, String>>> vocesEspanol() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return [];
      final voces = raw
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry('$k', '$v')))
          .where((v) => (v['locale'] ?? '').toLowerCase().startsWith('es') && !(v['features'] ?? '').contains('notInstalled'))
          .toList();
      voces.sort((a, b) => puntaje(b).compareTo(puntaje(a)));
      return voces;
    } catch (_) {
      return [];
    }
  }

  /// Mayor = mejor: calidad declarada por el motor, acento latinoamericano y voces de red (más naturales).
  @visibleForTesting
  static int puntaje(Map<String, String> v) {
    const calidad = {'very high': 4, 'high': 3, 'normal': 2, 'low': 1, 'very low': 0};
    final loc = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
    final acento = loc == 'es-es' ? 2 : 5; // español de España suena menos natural para un público peruano
    return (calidad[v['quality']] ?? 1) * 10 + acento + (v['network_required'] == '1' ? 1 : 0);
  }

  Future<void> _aplicarVozGuardadaOMejor() async {
    final voces = await vocesEspanol();
    if (voces.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString(_kNombre), l = prefs.getString(_kLocale);
    final guardada = voces.where((v) => v['name'] == n && v['locale'] == l);
    await _poner(guardada.isNotEmpty ? guardada.first : voces.first);
  }

  Future<void> _poner(Map<String, String> v) async {
    await _tts.setVoice({'name': v['name']!, 'locale': v['locale']!});
    _vozActual = v;
  }

  Future<void> elegirVoz(Map<String, String> v) async {
    await _poner(v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNombre, v['name']!);
    await prefs.setString(_kLocale, v['locale']!);
  }

  // ---------------------------------------------------------------- lectura
  Future<void> hablar(String texto, {VoidCallback? alTerminar}) async {
    final sesion = ++_sesion;
    await _tts.stop();
    for (final frase in frases(normalizar(texto))) {
      if (sesion != _sesion) return; // se pidió detener o leer otra cosa
      await _tts.speak(frase);
      await Future.delayed(const Duration(milliseconds: 120));
    }
    if (sesion == _sesion) alTerminar?.call();
  }

  Future<void> detener() async {
    _sesion++;
    await _tts.stop();
  }

  // ---------------------------------------------------------------- texto
  /// Deja el texto como se diría en voz alta.
  @visibleForTesting
  static String normalizar(String texto) {
    var s = texto;
    s = s.replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]', unicode: true), '');
    s = s.replaceAll(RegExp(r'[*#`_]+'), '');
    s = s.replaceAllMapped(RegExp(r'\bP\s*:\s*(\d+(?:[.,]\d+)?)\s*g\b'), (m) => 'proteína ${m[1]} gramos');
    s = s.replaceAllMapped(RegExp(r'\bC\s*:\s*(\d+(?:[.,]\d+)?)\s*g\b'), (m) => 'carbohidratos ${m[1]} gramos');
    s = s.replaceAllMapped(RegExp(r'\bG\s*:\s*(\d+(?:[.,]\d+)?)\s*g\b'), (m) => 'grasas ${m[1]} gramos');
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*[x×]\s*(\d+)\b', caseSensitive: false), (m) => '${m[1]} series de ${m[2]}');
    s = s.replaceAllMapped(RegExp(r'(\d)\s*/\s*(\d)'), (m) => '${m[1]} de ${m[2]}');
    s = s.replaceAllMapped(RegExp(r'(\d)\.(\d)'), (m) => '${m[1]},${m[2]}');
    s = s.replaceAll('%', ' por ciento');
    s = s.replaceAll('~', ' aproximadamente ');
    s = s.replaceAll('×', ' por ');
    s = s.replaceAll('→', ', ');
    s = s.replaceAll(RegExp(r'kcal', caseSensitive: false), 'kilocalorías');
    s = s.replaceAll(RegExp(r'\bkJ\b'), 'kilojulios');
    s = s.replaceAll(RegExp(r'\bmg\b'), 'miligramos');
    s = s.replaceAll(RegExp(r'\bkg\b', caseSensitive: false), 'kilos');
    s = s.replaceAll(RegExp(r'\bml\b', caseSensitive: false), 'mililitros');
    s = s.replaceAll(RegExp(r'\bmin\b', caseSensitive: false), 'minutos');
    s = s.replaceAll(RegExp(r'(?<=\d)\s*g\b'), ' gramos');
    s = s.replaceAll(RegExp(r'\bg\b'), 'gramos');
    s = s.replaceAll(RegExp(r'[•]|\s[-–—]\s'), ', ');
    s = s.replaceAll(RegExp(r'[()]'), ', ');
    s = s.replaceAll(RegExp(r'\s*,(\s*,)+'), ',').replaceAll(RegExp(r'\s+,'), ',');
    return s.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[,\s]+$'), '').trim();
  }

  /// Parte en frases y junta las muy cortas con la siguiente para que no suene entrecortado.
  @visibleForTesting
  static List<String> frases(String texto) {
    final partes = texto.split(RegExp(r'(?<=[.!?…:;])\s+')).where((p) => p.trim().isNotEmpty).toList();
    final salida = <String>[];
    var acumulada = '';
    for (final p in partes) {
      acumulada = acumulada.isEmpty ? p : '$acumulada $p';
      if (acumulada.length >= 25) {
        salida.add(acumulada);
        acumulada = '';
      }
    }
    if (acumulada.isNotEmpty) salida.isEmpty ? salida.add(acumulada) : salida[salida.length - 1] += ' $acumulada';
    return salida;
  }
}
