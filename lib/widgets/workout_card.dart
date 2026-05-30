import 'package:flutter/material.dart';
import '../models/assistant_response.dart';
import 'assistant_text_helpers.dart';
import 'app_components.dart';

class WorkoutCard extends StatelessWidget {
  final Section section;
  final VoidCallback? onAdd;
  final VoidCallback? onSave;

  const WorkoutCard({Key? key, required this.section, this.onAdd, this.onSave})
      : super(key: key);

  String get _nombreLimpio => section.nombre.replaceAll('**', '').trim();

  @override
  Widget build(BuildContext context) {
    final circuito = _circuitoListWidgets(section.ingredientes);
    final instrucciones = _instruccionesListWidgets(section.preparacion);
    final hayCircuito = circuito.isNotEmpty;
    final hayInstrucciones = instrucciones.isNotEmpty;

    return ExpandableCard(
      accent: Colors.blue,
      headerIcon: Icons.fitness_center,
      title: _nombreLimpio.toUpperCase(),
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.local_fire_department, size: 14, color: Colors.red),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              section.macros.trim().isEmpty
                  ? 'Gasto según duración e intensidad'
                  : section.macros,
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
      action: onSave != null ? CardSaveButton(onPressed: onSave!) : null,
      expandedContent: [
        CardSectionHeader(
          title: 'TÉCNICA Y PASOS',
          icon: Icons.accessibility_new,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 8),
        if (hayInstrucciones)
          ...instrucciones
        else
          _cajaVacia(
            'Sin descripción paso a paso. Pide al asistente: '
            '«explica la técnica de $_nombreLimpio paso a paso».',
          ),
        const Divider(height: 28),
        CardSectionHeader(
          title: 'MÚSCULO, EQUIPO Y VOLUMEN',
          icon: Icons.list_alt,
          color: Colors.blue.shade700,
        ),
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
        if (section.nota.isNotEmpty) ...[
          const SizedBox(height: 8),
          CardNoteBox(nota: section.nota, accent: Colors.blue),
        ],
      ],
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
        w.add(CardStepRow(stepIndex, stripMarkdownLight(raw), accent));
      }
    }
    return w;
  }
}
