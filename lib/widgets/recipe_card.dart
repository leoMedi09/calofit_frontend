import 'package:flutter/material.dart';
import '../models/assistant_response.dart';

class RecipeCard extends StatelessWidget {
  final Section section;
  final VoidCallback? onAdd;
  final VoidCallback? onSave;

  const RecipeCard({Key? key, required this.section, this.onAdd, this.onSave})
      : super(key: key);

  /// Parsea "P: 9.4g | C: 18.4g | G: 15.2g | Cal: 350kcal" → Map
  Map<String, String> _parseMacros(String macros) {
    final result = <String, String>{};
    if (macros.isEmpty) return result;
    
    // v66: Estrategia de Split Ultra-Robusta
    // 1. Normalizar separadores: Reemplazar '|' y ';' por comas
    String text = macros.replaceAll('|', ',').replaceAll(';', ',');
    
    // 2. Proteger decimales (ej: 30,5 -> 30.5) temporalmente para no partir por la coma
    // Buscamos coma entre dos números
    text = text.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');
    
    // 3. Ahora sí, partir por comas con confianza
    for (final pair in text.split(',')) {
      final parts = pair.trim().split(':');
      if (parts.length >= 2) {
        String key = parts[0].trim();
        // Mapeo flexible de llaves (P, C, G, Cal)
        if (key.toLowerCase().startsWith('p')) key = 'P';
        else if (key.toLowerCase().contains('cal')) key = 'Cal'; // Cal antes que C
        else if (key.toLowerCase().startsWith('c')) key = 'C';
        else if (key.toLowerCase().startsWith('g')) key = 'G';
        else continue;
        
        // El valor es el resto, volviendo a poner la coma si se prefiere (o dejar el punto)
        String val = parts.sublist(1).join(':').trim();
        // Limpiar comentarios entre paréntesis
        val = val.replaceAll(RegExp(r'\(.*?\)'), '').trim();
        result[key] = val;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final macrosMap = _parseMacros(section.macros);
    final hasMacros = macrosMap.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade900.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.orange.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.restaurant_menu,
              color: Colors.orange, size: 20),
        ),
        trailing: (onAdd != null || onSave != null)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onAdd != null)
                    IconButton(
                      icon: const Icon(Icons.add_task, color: Colors.teal),
                      onPressed: onAdd,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Registrar',
                    ),
                  if (onSave != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.bookmark_add, color: Colors.blue),
                      onPressed: onSave,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Guardar',
                    ),
                  ],
                ],
              )
            : null,
        title: Text(
          section.nombre.replaceAll('**', '').trim().toUpperCase(),
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        // Chips de macros visibles SIN expandir
        subtitle: hasMacros
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _MacroChipsRow(macrosMap: macrosMap),
              )
            : section.macros.isNotEmpty
                ? Text(section.macros,
                    style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)
                : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel detallado de macros al expandir
          if (hasMacros) ...[
            _MacroDetailPanel(macrosMap: macrosMap),
            const SizedBox(height: 16),
          ],

          _sectionHeader('INGREDIENTES', Icons.shopping_basket),
          const SizedBox(height: 8),
          ...section.ingredientes
              .map((i) => _itemRow(i, Icons.check_circle_outline, Colors.orange)),
          const Divider(height: 32),
          _sectionHeader('PREPARACIÓN', Icons.list),
          const SizedBox(height: 8),
          ...section.preparacion.asMap().entries
              .map((e) => _stepRow(e.key + 1, e.value, Colors.orange)),



          if (section.nota.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.nota,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.grey.shade600),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              letterSpacing: 1.1)),
    ]);
  }

  Widget _itemRow(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color.withOpacity(0.5)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Widget _stepRow(int index, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$index.',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chips compactos de macros (visibles sin expandir)
// ─────────────────────────────────────────────────────────────────────────────
class _MacroChipsRow extends StatelessWidget {
  final Map<String, String> macrosMap;
  const _MacroChipsRow({required this.macrosMap});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 4, children: [
      if (macrosMap.containsKey('Cal'))
        _chip('🔥 ${macrosMap['Cal']}', Colors.orange.shade700,
            Colors.orange.shade50),
      if (macrosMap.containsKey('P'))
        _chip('💪 P: ${macrosMap['P']}', Colors.blue.shade700,
            Colors.blue.shade50),
      if (macrosMap.containsKey('C'))
        _chip('🌾 C: ${macrosMap['C']}', Colors.amber.shade800,
            Colors.amber.shade50),
      if (macrosMap.containsKey('G'))
        _chip('🥑 G: ${macrosMap['G']}', Colors.green.shade700,
            Colors.green.shade50),
    ]);
  }

  Widget _chip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel detallado de macros (visible al expandir)
// ─────────────────────────────────────────────────────────────────────────────
class _MacroDetailPanel extends StatelessWidget {
  final Map<String, String> macrosMap;
  const _MacroDetailPanel({required this.macrosMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.deepOrange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Encabezado
        Row(children: [
          Icon(Icons.analytics_outlined, size: 14, color: Colors.orange.shade800),
          const SizedBox(width: 6),
          Text('INFORMACIÓN NUTRICIONAL',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                  letterSpacing: 1.0)),
        ]),
        const SizedBox(height: 12),

        // Calorías (tarjeta grande) + macros (barras)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (macrosMap.containsKey('Cal')) ...[
            _CalCard(calories: macrosMap['Cal']!),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(children: [
              if (macrosMap.containsKey('P'))
                _MacroRow('Proteína', macrosMap['P']!,
                    Colors.blue.shade400, Icons.fitness_center),
              if (macrosMap.containsKey('C'))
                _MacroRow('Carbos', macrosMap['C']!,
                    Colors.amber.shade600, Icons.grain),
              if (macrosMap.containsKey('G'))
                _MacroRow('Grasas', macrosMap['G']!,
                    Colors.green.shade500, Icons.water_drop),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _CalCard extends StatelessWidget {
  final String calories;
  const _CalCard({required this.calories});

  @override
  Widget build(BuildContext context) {
    final numStr = calories.replaceAll('kcal', '').trim();
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade600,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔥', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(numStr,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const Text('kcal',
            style: TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MacroRow(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      ]),
    );
  }
}
