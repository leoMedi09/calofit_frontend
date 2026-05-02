// Formato de texto del asistente (sin dependencias de UI).
// Convierte viñetas • en una sola línea a listas Markdown legibles.

final _reBulletSplit = RegExp(r'\s*[•·]\s+');

bool _lineLooksLikeFoodOrRecipeList(String line) {
  final l = line.toLowerCase();
  if (l.contains('kcal')) return true;
  if (RegExp(r'\d+\s*g\b').hasMatch(line)) return true;
  if (RegExp(r'\bingredientes\b').hasMatch(l)) return true;
  if (RegExp(r'\bpreparaci[oó]n\b').hasMatch(l)) return true;
  if (RegExp(r'\bpasos\b').hasMatch(l)) return true;
  return false;
}

/// Parte párrafos con varias `•` en líneas tipo `- ítem` para que flutter_markdown renderice lista.
String expandInlineBulletsForMarkdown(String text) {
  if (text.isEmpty) return text;
  final out = <String>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine;
    if (!line.contains(RegExp(r'[•·]'))) {
      out.add(rawLine);
      continue;
    }
    final normalized =
        line.trimLeft().replaceFirst(RegExp(r'^[•·]\s*'), '');
    final parts = normalized
        .split(_reBulletSplit)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      out.add(rawLine);
      continue;
    }
    final longList = parts.length >= 4;
    if (!longList && !_lineLooksLikeFoodOrRecipeList(line)) {
      out.add(rawLine);
      continue;
    }
    final first = parts.first;
    final rest = parts.skip(1).toList();
    final firstIsIntro = RegExp(
      r'ingredientes|preparaci|pasos|opción|opcion|\*\*|🍎|🥗|🍽|🥑|🍳',
      caseSensitive: false,
    ).hasMatch(first);
    if (firstIsIntro && rest.isNotEmpty) {
      out.add(first);
      out.add('');
      for (final r in rest) {
        out.add('- $r');
      }
    } else {
      for (final p in parts) {
        out.add('- $p');
      }
    }
  }
  return out.join('\n');
}

/// Si el backend manda cadenas con varias `•`, las parte en entradas separadas (ingredientes o pasos).
List<String> expandBulletSeparatedLines(List<String> items) {
  final out = <String>[];
  for (final raw in items) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (!t.contains(RegExp(r'[•·]'))) {
      out.add(t);
      continue;
    }
    final norm = t.replaceFirst(RegExp(r'^[•·]\s*'), '');
    final chunks = norm
        .split(_reBulletSplit)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (chunks.length >= 2) {
      out.addAll(chunks);
    } else {
      out.add(t);
    }
  }
  return out;
}
