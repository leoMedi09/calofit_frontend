import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/assistant_response.dart';

/// Nueva arquitectura de burbujas — 3 tipos únicos:
///   1. _ConversationalBubble  → chat, consejos, preguntas (INFO/OTRO)
///   2. _RegistrationPill      → confirmación de registro (LOG/SUCCESS)
///   3. _RecommendationBubble  → sugerencias de comida/ejercicio (RECIPE/POWER)

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
    final isRecomendacion = intent == 'RECIPE' || intent == 'POWER' ||
        tipo.contains('RECOMENDAR');

    final texto = response.respuestaEstructurada.textoConversacional.trim();
    final progress = response.dataCientifica.progresoDiario;
    final datos = response.datos ?? {};

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──────────────────────────────────────────────
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
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),

          // ── Contenido ───────────────────────────────────────────
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
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 13,
                          color: const Color(0xFF059669).withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Sugerencias optimizadas por KNN Coseno (MINSA/INS)",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669).withOpacity(0.8),
                            letterSpacing: 0.2,
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

// ════════════════════════════════════════════════════════════════════════════
// 1. BURBUJA CONVERSACIONAL — chat, consejos, dudas
// ════════════════════════════════════════════════════════════════════════════

class _ConversationalBubble extends StatelessWidget {
  final String texto;
  const _ConversationalBubble({required this.texto});

  @override
  Widget build(BuildContext context) {
    if (texto.isEmpty) return const SizedBox.shrink();
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
      child: MarkdownBody(
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
        ),
        shrinkWrap: true,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 2. PILL DE REGISTRO — confirmación de comida o ejercicio
// ════════════════════════════════════════════════════════════════════════════

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

  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  String? _alertaDieta() => datos['alerta_dieta'] as String?;

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

    // ── Registro de COMIDA ──────────────────────────────────────
    final kcal = _toDouble(datos['calorias']);
    final prot = _toDouble(datos['proteinas_g']);
    final carb = _toDouble(datos['carbohidratos_g']);
    final grasa = _toDouble(datos['grasas_g']);
    // Lista completa de alimentos (backend envía todos los ítems)
    final alimentosLista = (datos['alimentos_lista'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        (nombre.isNotEmpty ? [nombre] : []);

    return _PillCard(
      color: const Color(0xFF059669),
      lightColor: const Color(0xFFF0FDF4),
      borderColor: const Color(0xFFBBF7D0),
      icon: Icons.check_circle_rounded,
      label: 'Registrado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lista de alimentos — muestra TODOS (no "y X más")
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
              children: alimentosLista.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                    Expanded(child: Text(
                      a,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF064E3B),
                        fontWeight: FontWeight.w500,
                      ),
                    )),
                  ],
                ),
              )).toList(),
            ),
          const SizedBox(height: 8),

          // kcal principal
          if (kcal > 0)
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 18, color: Color(0xFFDC2626)),
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

          // Macros en fila
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

          // Alerta dietética (vegano/vegetariano comió algo no permitido)
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

          // Progreso del día
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
                    color: pct >= 100
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
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
                  pct >= 100
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 3. BURBUJA DE RECOMENDACIÓN — comida o ejercicio sugerido
// ════════════════════════════════════════════════════════════════════════════

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
          ? MarkdownBody(
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
            )
          : const SizedBox.shrink(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPERS — componentes compartidos
// ════════════════════════════════════════════════════════════════════════════

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
            color: color.withValues(alpha:0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header chip
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
        color: color.withValues(alpha:0.1),
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
        color: color.withValues(alpha:0.1),
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
