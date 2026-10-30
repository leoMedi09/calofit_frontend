import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/assistant_response.dart';

class AssistantMessageBubble extends StatelessWidget {
  final AssistantResponse response;
  final Function(String)? onAction;

  const AssistantMessageBubble({
    super.key,
    required this.response,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final intent = (response.intencion ?? 'INFO').toUpperCase();
    final tipo = (response.tipoPregunta ?? '').toUpperCase();
    final isRegistro = intent == 'SUCCESS' || tipo == 'LOG';
    final isEjercicioReg = isRegistro && (response.datos?['kcal_quemadas'] != null);
    final isRecomendacion = intent == 'RECIPE' || intent == 'POWER' || tipo.contains('RECOMENDAR');

    final texto = response.respuestaEstructurada.textoConversacional.trim();
    final progress = response.dataCientifica.progresoDiario;
    final datos = response.datos ?? {};

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRegistro)
                  _RegistrationPill(
                    texto: texto,
                    datos: datos,
                    progress: progress,
                    esEjercicio: isEjercicioReg,
                  )
                else if (isRecomendacion) ...[
                  _RecommendationBubble(texto: texto, intent: intent),
                  const SizedBox(height: 5),
                  Container(
                    margin: const EdgeInsets.only(left: 2, top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.psychology_outlined, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            intent == 'POWER'
                                ? "Adaptada a tu objetivo y condiciones de salud"
                                : "Sugerencias optimizadas por KNN Coseno (MINSA/INS)",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  _ConversationalBubble(texto: texto),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BubbleType { chat, receta, tecnica }

class _ConversationalBubble extends StatelessWidget {
  final String texto;
  const _ConversationalBubble({required this.texto});

  _BubbleType _detectarTipo() {
    final t = texto.toLowerCase();
    if (t.contains('ingredientes:') || t.contains('preparación:') || t.contains('preparacion:')) {
      return _BubbleType.receta;
    }
    const ejerciciosKw = [
      'press',
      'sentadilla',
      'curl',
      'remo',
      'dominada',
      'fondos',
      'peso muerto',
      'plancha',
      'burpee',
      'bíceps',
      'biceps',
      'tríceps',
      'triceps',
      'pecho',
      'espalda',
      'pierna',
      'hombro'
    ];
    if (ejerciciosKw.any((k) => t.contains(k)) && (t.contains('1.') || t.contains('2.') || t.contains('paso'))) {
      return _BubbleType.tecnica;
    }
    return _BubbleType.chat;
  }

  @override
  Widget build(BuildContext context) {
    if (texto.isEmpty) return const SizedBox.shrink();
    final tipo = _detectarTipo();
    final Color? badgeColor = tipo == _BubbleType.receta
        ? const Color(0xFFD97706)
        : tipo == _BubbleType.tecnica
            ? const Color(0xFF2563EB)
            : null;
    final String? badgeLabel = tipo == _BubbleType.receta
        ? '🍽 Receta'
        : tipo == _BubbleType.tecnica
            ? '💪 Técnica'
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(
          color: badgeColor?.withValues(alpha: 0.3) ?? const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badgeLabel != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor!.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
          MarkdownBody(
            data: texto,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), height: 1.55),
              listBullet: TextStyle(fontSize: 15, color: badgeColor ?? const Color(0xFF1E293B)),
              strong: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
              orderedListAlign: WrapAlignment.start,
            ),
            shrinkWrap: true,
          ),
        ],
      ),
    );
  }
}

class _RegistrationPill extends StatelessWidget {
  final String texto;
  final Map<String, dynamic> datos;
  final Map<String, dynamic> progress;
  final bool esEjercicio;

  const _RegistrationPill({
    required this.texto,
    required this.datos,
    required this.progress,
    required this.esEjercicio,
  });

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  String? _alertaDieta() => datos['alerta_dieta'] as String?;
  String? _advertenciaCantidad() => datos['advertencia_cantidad'] as String?;

  @override
  Widget build(BuildContext context) {
    final nombre = datos['nombre']?.toString() ?? '';
    final consumido = _toDouble(progress['consumido']);
    final meta = _toDouble(progress['meta']);
    final quemado = _toDouble(progress['quemado']);
    final pct = meta > 0 ? ((consumido / meta) * 100).clamp(0, 100) : 0.0;

    if (esEjercicio) {
      final kcal = _toDouble(datos['kcal_quemadas']);
      final dur = _toDouble(datos['duracion_min']).toInt();
      final series = datos['series'];
      final reps = datos['reps'];
      final peso = datos['peso_kg'];
      final calculos = (datos['calculos'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      final fuente = datos['fuente']?.toString() ?? '';

      String detalle = '${dur}min';
      if (series != null && reps != null) {
        detalle = '$series×$reps';
        if (peso != null) detalle += ' @${peso}kg';
      }

      return _PillCard(
        color: const Color(0xFF2563EB),
        lightColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFFBFDBFE),
        icon: Icons.fitness_center_rounded,
        label: 'Ejercicio Registrado',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre.isNotEmpty ? nombre : texto,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _StatChip(
                  icon: Icons.local_fire_department_rounded,
                  value: '${kcal.round()} kcal',
                  color: const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.timer_outlined,
                  value: detalle,
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
            if (calculos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Cálculo considerado',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
              ),
              const SizedBox(height: 2),
              for (final c in calculos)
                Text(c, style: TextStyle(fontSize: 12, color: Colors.blue.shade900.withValues(alpha: 0.8))),
              const SizedBox(height: 3),
              Text(
                'MET: energía que gasta el ejercicio frente a estar en reposo.',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, height: 1.3),
              ),
              if (fuente.isNotEmpty)
                Text('Fuente: $fuente', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, height: 1.3)),
            ],
            if (quemado > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Total quemado hoy: ${quemado.toInt()} kcal',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final kcal = _toDouble(datos['calorias']);
    final prot = _toDouble(datos['proteinas_g']);
    final carb = _toDouble(datos['carbohidratos_g']);
    final grasa = _toDouble(datos['grasas_g']);
    final alimentosLista =
        (datos['alimentos_lista'] as List?)?.map((e) => e.toString()).toList() ?? (nombre.isNotEmpty ? [nombre] : []);
    final porciones = (datos['porciones'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

    return _PillCard(
      color: const Color(0xFF059669),
      lightColor: const Color(0xFFF0FDF4),
      borderColor: const Color(0xFFBBF7D0),
      icon: Icons.check_circle_rounded,
      label: 'Registrado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alimentosLista.length <= 3)
            Text(
              alimentosLista.join(' + '),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF064E3B),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: alimentosLista
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                )),
                            Expanded(
                                child: Text(
                              a,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF064E3B),
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          if (porciones.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Cantidad considerada',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade800),
            ),
            const SizedBox(height: 2),
            for (final p in porciones)
              Text(p, style: TextStyle(fontSize: 12, color: Colors.green.shade900.withValues(alpha: 0.8))),
          ],
          const SizedBox(height: 8),
          if (kcal >= 0)
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Text(
                  '${kcal.round()} kcal',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF064E3B),
                  ),
                ),
              ],
            ),
          if (prot > 0 || carb > 0 || grasa > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _MacroPill(label: 'P', value: prot, color: const Color(0xFF2563EB)),
                const SizedBox(width: 6),
                _MacroPill(label: 'C', value: carb, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _MacroPill(label: 'G', value: grasa, color: const Color(0xFFEF4444)),
              ],
            ),
          ],
          if (_alertaDieta() != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Text(
                _alertaDieta()!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (_advertenciaCantidad() != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Text(
                _advertenciaCantidad()!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Valores aproximados para la cantidad considerada; pueden variar según la preparación.',
            style: TextStyle(fontSize: 10.5, color: Colors.green.shade900.withValues(alpha: 0.6), height: 1.3),
          ),
          if (consumido > 0 && meta > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFD1FAE5)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hoy: ${consumido.toInt()} / ${meta.toInt()} kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${pct.toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: pct >= 100 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: const Color(0xFFD1FAE5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 100 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationBubble extends StatelessWidget {
  final String texto;
  final String intent;
  const _RecommendationBubble({required this.texto, required this.intent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: texto.isNotEmpty
          ? (_parsear(texto) != null
              ? _lista(_parsear(texto)!)
              : (intent == 'POWER' && _parsearEjercicios(texto) != null)
                  ? _listaEjercicios(_parsearEjercicios(texto)!)
                  : MarkdownBody(
              data: texto,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  height: 1.55,
                ),
                listBullet: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
                strong: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                ),
                h3: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              shrinkWrap: true,
            ))
          : const SizedBox.shrink(),
    );
  }

  static final _rxPlato = RegExp(r'([^,()\n]+?)\s*\(\s*~?\s*(\d+)\s*kcal\s*\)');
  static final _rxIntro = RegExp(
    r'^(.*?\b(?:propongo|recomiendo|sugiero|sugeriría|recomendaría|ofrezco)\b:?)\s+(.+)$',
    caseSensitive: false,
  );

  /// Si el texto es la frase simple "…te propongo A (~700 kcal), B (~600 kcal) y C (~750 kcal)." devuelve
  /// (intro, [(plato, kcal)]) para dibujarlo como lista. Si trae viñetas, saltos de línea o menos de 2
  /// platos devuelve null y se muestra el texto tal cual (Markdown).
  static ({String intro, List<(String, String)> platos})? _parsear(String t) {
    if (t.contains('\n') || t.contains('*') || t.contains('- ')) return null;
    final ms = _rxPlato.allMatches(t).toList();
    if (ms.length < 2 || !_huecosValidos(t, ms)) return null;
    var intro = '';
    final platos = <(String, String)>[];
    for (var i = 0; i < ms.length; i++) {
      var nombre = ms[i].group(1)!.trim().replaceFirst(RegExp(r'^(y|e)\s+', caseSensitive: false), '');
      if (i == 0) {
        final m = _rxIntro.firstMatch(nombre);
        if (m != null) {
          intro = _unir(t.substring(0, ms[0].start), m.group(1)!); // el texto previo puede tener comas
          nombre = m.group(2)!;
        }
      }
      if (nombre.isEmpty) return null;
      platos.add((nombre[0].toUpperCase() + nombre.substring(1), ms[i].group(2)!));
    }
    return (intro: intro, platos: platos);
  }

  /// Entre un elemento y el siguiente solo puede haber separadores (coma o punto y coma). Si hay texto
  /// explicativo en medio, las tarjetas lo perderían: en ese caso se muestra el mensaje completo como texto.
  static bool _huecosValidos(String t, List<RegExpMatch> ms) {
    for (var i = 0; i < ms.length - 1; i++) {
      if (!RegExp(r'^[\s,;]*$').hasMatch(t.substring(ms[i].end, ms[i + 1].start))) return false;
    }
    return true;
  }

  static String _unir(String previo, String verbo) => '$previo $verbo'.replaceAll(RegExp(r'\s+'), ' ').trim();

  static final _rxEjercicio =RegExp(r'([^,.;:()\n]+?)\s+(\d+)\s*[x×]\s*(\d+)\b', caseSensitive: false);

  /// "…te sugiero Sentadilla Libre 3x10, Prensa de Piernas 3x12 y Peso Muerto 3x10. ¡Dale con todo!"
  /// → (intro, [(ejercicio, "3 × 10")], cierre). Con menos de 2 ejercicios devuelve null (se muestra el texto tal cual).
  static ({String intro, List<(String, String)> items, String cierre})? _parsearEjercicios(String t) {
    if (t.contains('\n') || t.contains('*') || t.contains('- ')) return null;
    final ms = _rxEjercicio.allMatches(t).toList();
    if (ms.length < 2 || !_huecosValidos(t, ms)) return null;
    var intro = '';
    final items = <(String, String)>[];
    for (var i = 0; i < ms.length; i++) {
      var nombre = ms[i].group(1)!.trim().replaceFirst(RegExp(r'^(y|e)\s+', caseSensitive: false), '');
      if (i == 0) {
        final m = _rxIntro.firstMatch(nombre);
        if (m != null) {
          intro = _unir(t.substring(0, ms[0].start), m.group(1)!); // el texto previo puede tener comas
          nombre = m.group(2)!;
        }
      }
      if (nombre.isEmpty) return null;
      items.add((nombre[0].toUpperCase() + nombre.substring(1), '${ms[i].group(2)} × ${ms[i].group(3)}'));
    }
    var cierre = t.substring(ms.last.end).replaceFirst(RegExp(r'^[\s.,;:]+'), '').trim();
    if (cierre.length < 3) cierre = '';
    return (intro: intro, items: items, cierre: cierre);
  }

  Widget _listaEjercicios(({String intro, List<(String, String)> items, String cierre}) d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (d.intro.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              d.intro,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
        for (final e in d.items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fitness_center_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.$1,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  e.$2,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        if (d.cierre.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(d.cierre, style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4)),
          ),
      ],
    );
  }

  Widget _lista(({String intro, List<(String, String)> platos}) d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (d.intro.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              d.intro,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
        for (final p in d.platos)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_rounded, size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.$1,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF064E3B)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '~${p.$2} kcal',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PillCard extends StatelessWidget {
  final Color color;
  final Color lightColor;
  final Color borderColor;
  final IconData icon;
  final String label;
  final Widget child;

  const _PillCard({
    required this.color,
    required this.lightColor,
    required this.borderColor,
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.round()}g',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
