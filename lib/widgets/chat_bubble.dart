import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/assistant_response.dart';
import 'calorie_progress_card.dart';
import 'recipe_card.dart';
import 'workout_card.dart';

class AssistantMessageBubble extends StatelessWidget {
  final AssistantResponse response;
  final Function(String)? onAction;

  const AssistantMessageBubble({Key? key, required this.response, this.onAction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Escudo de Salud (v11.1)
    final bool hasAlert = response.alertaSalud == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: hasAlert ? Colors.red : const Color(0xFF1E88E5),
            child: Icon(
              hasAlert ? Icons.warning_amber_rounded : Icons.auto_awesome,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Mostrar Progreso Calórico (Si aplica y hay datos de consumo)
                if (response.dataCientifica.progresoDiario.isNotEmpty && 
                    (response.dataCientifica.progresoDiario['consumido'] ?? 0) > 0)
                  CalorieProgressMiniCard(data: response.dataCientifica.progresoDiario),

                // 2. El texto de la IA (Burbuja estilizada)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasAlert ? Colors.red.shade50 : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4), // Little sharper point for bubble feel
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: hasAlert ? Colors.red.shade200 : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: _cleanResponseText(
                      response.respuestaEstructurada.textoConversacional,
                      response.respuestaEstructurada.secciones,
                    ),
                    selectable: true, // Permitir copiar texto
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: hasAlert ? Colors.red.shade900 : Colors.black87,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasAlert ? Colors.red : const Color(0xFF2563EB),
                      ),
                      // Estilo mejorado para tablas
                      tableHead: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      tableBorder: TableBorder.all(color: Colors.grey.shade300, width: 1),
                      tableBody: const TextStyle(fontSize: 14),
                      blockquote: TextStyle(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.blue.shade300, width: 4)),
                        color: Colors.blue.shade50,
                      ),
                      code: TextStyle(
                        backgroundColor: Colors.grey.shade100,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // 3. Renderizar Secciones Especiales (Recetas o Ejercicios)
                ...response.respuestaEstructurada.secciones.map((sec) {
                  if (sec.tipo == 'comida') {
                    return RecipeCard(
                      section: sec,
                      onAdd: onAction != null ? () => onAction!("Comí ${sec.nombre}") : null,
                    );
                  }
                  if (sec.tipo == 'ejercicio') {
                    return WorkoutCard(
                      section: sec,
                      onAdd: onAction != null ? () => onAction!("Hice ${sec.nombre}") : null,
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),

                // 4. Advertencia Nutricional (Si existe)
                if (response.advertencia != null) 
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      "ℹ️ ${response.advertencia}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cleanResponseText(String text, List<Section> sections) {
    try {
      // 1. Eliminar TODAS las etiquetas CALOFIT (apertura Y cierre)
      String cleaned = text.replaceAll(RegExp(r'\[/?CALOFIT_[A-Z_]+(?:[:\s].*?)?\]'), '');

      // 2. Transformar Tablas Markdown en Listas Legibles (Verticales)
      if (RegExp(r'\|[\s-:]+\|').hasMatch(cleaned)) {
        cleaned = cleaned.replaceAll(RegExp(r'^.*\|[\s-:]+\|.*$', multiLine: true), '');
        List<String> lines = cleaned.split('\n');
        for (int i = 0; i < lines.length; i++) {
          String line = lines[i].trim();
          if (line.contains('|')) {
            if (line.startsWith('|')) line = line.substring(1);
            if (line.endsWith('|')) line = line.substring(0, line.length - 1);
            List<String> cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
            if (cells.length >= 2) {
               String name = cells[0].replaceAll('**', '').replaceAll('*', '').trim();
               lines[i] = '* **$name**: ${cells.sublist(1).join(" | ")}';
            } else if (cells.length == 1) {
               String item = cells[0].trim();
               if (item.startsWith('*') || item.startsWith('-')) {
                 lines[i] = item;
               } else {
                 lines[i] = '* $item';
               }
            }
          }
        }
        cleaned = lines.join('\n');
      }
      
      // 4. ELIMINACIÓN AGRESIVA DE NOMBRES REPETIDOS
      List<String> lines = cleaned.split('\n');
      List<String> sectionNames = sections.map((s) => s.nombre.toLowerCase().replaceAll('**', '').trim()).toList();
      
      List<String> finalLines = [];
      for (String line in lines) {
        String lineLower = line.toLowerCase();
        String lineClean = lineLower.replaceAll('**', '').replaceAll('*', '').replaceAll('-', '').trim();
        
        bool isRepeatedName = sectionNames.any((name) {
          if (name.isEmpty) return false;
          if (lineClean == name) return true;
          if (lineClean.contains(name) && lineClean.length <= name.length + 5) return true;
          if (name.length > 10 && lineClean.contains(name.substring(0, 10)) && lineClean.length < 50) return true;
          return false;
        });
        
        if (!isRepeatedName && line.trim().isNotEmpty) {
          finalLines.add(line);
        }
      }
      
      return finalLines.join('\n').trim();
    } catch (e) {
      debugPrint("Error cleaning AI response: $e");
      return text; // Fallback al texto original
    }
  }
}
