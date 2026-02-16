import 'package:flutter/material.dart';
import '../models/assistant_response.dart';

class WorkoutCard extends StatelessWidget {
  final Section section;

  const WorkoutCard({Key? key, required this.section}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fitness_center, color: Colors.blue, size: 20),
        ),
        title: Text(
          section.nombre.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.local_fire_department, size: 14, color: Colors.red),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                section.macros, // En ejercicios, macros es el gasto calórico
                style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("CIRCUITO", Icons.list_alt),
          const SizedBox(height: 8),
          ...section.ingredientes.map((i) => _itemRow(i, Icons.bolt, Colors.blue)),
          const Divider(height: 32),
          _sectionHeader("INSTRUCCIONES TÉCNICAS", Icons.psychology),
          const SizedBox(height: 8),
          ...section.preparacion.asMap().entries.map((e) => 
            _stepRow(e.key + 1, e.value, Colors.blue)
          ),
          if (section.nota.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "💡 Técnica: ${section.nota}",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.blue.shade900,
                  fontSize: 12,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _itemRow(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.5)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text("$index", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
