import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/assistant_response.dart';
import 'calorie_progress_card.dart';
import 'recipe_card.dart';
import 'workout_card.dart';

class AssistantMessageBubble extends StatelessWidget {
  final AssistantResponse response;

  const AssistantMessageBubble({Key? key, required this.response}) : super(key: key);

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
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: hasAlert ? Colors.red.shade200 : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: MarkdownBody(
                    data: response.respuestaEstructurada.textoConversacional,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: hasAlert ? Colors.red.shade900 : Colors.black87,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasAlert ? Colors.red : const Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                ),

                // 3. Renderizar Secciones Especiales (Recetas o Ejercicios)
                ...response.respuestaEstructurada.secciones.map((sec) {
                  if (sec.tipo == 'comida') return RecipeCard(section: sec);
                  if (sec.tipo == 'ejercicio') return WorkoutCard(section: sec);
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
}
