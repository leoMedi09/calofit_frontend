import 'package:flutter/material.dart';
import '../models/assistant_response.dart';
import 'assistant_text_helpers.dart';

class WorkoutCard extends StatefulWidget {
  final Section section;
  final VoidCallback? onAdd;
  final VoidCallback? onSave;

  const WorkoutCard({Key? key, required this.section, this.onAdd, this.onSave})
      : super(key: key);

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  bool _expanded = false;

  String get _nombreLimpio => widget.section.nombre.replaceAll('**', '').trim();

  void _toggleExpand() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final circuito = _circuitoListWidgets(widget.section.ingredientes);
    final instrucciones = _instruccionesListWidgets(widget.section.preparacion);
    final hayCircuito = circuito.isNotEmpty;
    final hayInstrucciones = instrucciones.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (siempre visible) ──────────────────────────────────────
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fitness_center,
                        color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombreLimpio.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.local_fire_department,
                                  size: 14, color: Colors.red),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.section.macros.trim().isEmpty
                                    ? 'Gasto según duración e intensidad'
                                    : widget.section.macros,
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        if (widget.onSave != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.bookmark_add,
                                  size: 18, color: Colors.blue),
                              label: const Text('Guardar',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              onPressed: widget.onSave,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.blue.shade400, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido expandible (crece hacia abajo) ──────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _sectionHeader('TÉCNICA Y PASOS', Icons.accessibility_new),
                        const SizedBox(height: 8),
                        if (hayInstrucciones)
                          ...instrucciones
                        else
                          _cajaVacia(
                            'Sin descripción paso a paso. Pide al asistente: '
                            '«explica la técnica de $_nombreLimpio paso a paso».',
                          ),
                        const Divider(height: 28),
                        _sectionHeader(
                            'MÚSCULO, EQUIPO Y VOLUMEN', Icons.list_alt),
                        const SizedBox(height: 8),
                        if (hayCircuito)
                          ...circuito
                        else
                          _cajaVacia(
                            'Aquí irían series, repeticiones, peso o tiempo. '
                            'Vuelve a preguntar al asistente: '
                            '«detalla series y repeticiones de $_nombreLimpio».',
                          ),
                        const SizedBox(height: 8),
                        if (widget.section.nota.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 18, color: Colors.blue.shade800),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.section.nota,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue.shade900,
                                      fontSize: 12.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _cajaVacia(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        mensaje,
        style: TextStyle(fontSize: 12.5, height: 1.4, color: Colors.grey.shade800),
      ),
    );
  }

  List<Widget> _circuitoListWidgets(List<String> ejercicios) {
    const accent = Colors.blue;
    final w = <Widget>[];
    for (final raw in expandItemLines(ejercicios)) {
      if (isAssistantSubheader(raw)) {
        w.add(assistantSubheaderLine(
          stripMarkdownLight(raw),
          accent,
          isFirst: w.isEmpty,
        ));
      } else {
        w.add(assistantBulletLine(stripMarkdownLight(raw), accent));
      }
    }
    return w;
  }

  List<Widget> _instruccionesListWidgets(List<String> pasos) {
    const accent = Colors.blue;
    final w = <Widget>[];
    var stepIndex = 0;
    for (final raw in expandItemLines(pasos)) {
      if (isAssistantSubheader(raw)) {
        w.add(assistantSubheaderLine(
          stripMarkdownLight(raw),
          accent,
          isFirst: w.isEmpty,
        ));
      } else {
        stepIndex++;
        w.add(_stepRow(stepIndex, stripMarkdownLight(raw), accent));
      }
    }
    return w;
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _stepRow(int index, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
