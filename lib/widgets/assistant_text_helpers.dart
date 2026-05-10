import 'package:flutter/material.dart';

// Helpers para mostrar respuestas del asistente sin "fugas" de Markdown
// y distinguir subtítulos de ítems de lista.

/// Parte cadenas multilínea del backend en renglones individuales.
Iterable<String> expandItemLines(Iterable<String> items) sync* {
  for (final item in items) {
    for (final line in item.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isNotEmpty) yield t;
    }
  }
}

/// Quita marcadores Markdown típicos para mostrarlos en Text plano (tarjetas).
String stripMarkdownLight(String s) {
  var t = s.trim();
  t = t.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
  t = t.replaceAll('**', '');
  t = t.replaceAll(RegExp(r'^\[[^\]]+\]\s*'), '');
  if (t.startsWith('* ')) t = t.substring(2).trim();
  return t.trim();
}

/// Líneas que deben verse como subtítulo, no como viñeta con ícono.
bool isAssistantSubheader(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  if (RegExp(r'^#{1,6}\s').hasMatch(t)) return true;
  final s = stripMarkdownLight(t);
  if (RegExp(r'^Opción\s*\d+', caseSensitive: false).hasMatch(s)) return true;
  if (RegExp(
    r'^(Ingredientes|Preparación|Preparacion|Instrucciones|Instrucción|Modo|Nota|'
    r'Equipo|Músculo|Musculo|Series|Repeticiones|Volumen|Material|Técnica|Tecnica|Tip|Consejo).*:',
    caseSensitive: false,
  ).hasMatch(s)) {
    return true;
  }
  if (RegExp(
          r'^(Ingredientes|Preparación|Preparacion|Instrucciones|'
          r'Equipo|Músculo|Musculo|Series|Técnica|Tecnica|Tip|Consejo)\s*$',
          caseSensitive: false)
      .hasMatch(s)) {
    return true;
  }
  return false;
}

/// Subtítulo dentro de listas (sin viñeta).
Widget assistantSubheaderLine(String text, Color accent, {required bool isFirst}) {
  return Padding(
    padding: EdgeInsets.only(top: isFirst ? 0 : 14, bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: accent.withValues(alpha: 0.92),
        height: 1.3,
      ),
    ),
  );
}

/// Viñeta simple tipo texto (mejor que un ícono de check en cada línea).
Widget assistantBulletLine(String text, Color accent) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.6),
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
      ],
    ),
  );
}
