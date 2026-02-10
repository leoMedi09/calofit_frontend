import 'package:flutter/material.dart';

class PlanStatusBadge extends StatelessWidget {
  final String estadoPlan;
  final bool esCondicionCritica;

  const PlanStatusBadge({
    super.key,
    required this.estadoPlan,
    this.esCondicionCritica = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determinar color e ícono según el estado
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    switch (estadoPlan) {
      case 'validado':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        label = 'Validado';
        break;
      case 'modificado':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.edit;
        label = 'Personalizado';
        break;
      case 'en_revision':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.warning;
        label = 'Revisión Urgente';
        break;
      default: // provisional_ia
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.schedule;
        label = 'Provisional';
    }

    // Si es condición crítica, sobrescribir
    if (esCondicionCritica) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
      icon = Icons.local_hospital;
      label = 'Requiere Validación';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
