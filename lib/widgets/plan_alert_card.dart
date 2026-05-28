import 'package:flutter/material.dart';

class PlanAlertCard extends StatelessWidget {
  final String estadoPlan;
  final bool esCondicionCritica;
  final String mensajeCliente;
  final VoidCallback? onContactarNutricionista;

  const PlanAlertCard({
    super.key,
    required this.estadoPlan,
    this.esCondicionCritica = false,
    required this.mensajeCliente,
    this.onContactarNutricionista,
  });

  @override
  Widget build(BuildContext context) {
    // Plan validado sin condición crítica → banner verde de confianza
    if ((estadoPlan == 'validado' || estadoPlan == 'modificado') && !esCondicionCritica) {
      return Card(
        color: Colors.green.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '✅ Plan aprobado por tu nutricionista. ¡Sigue adelante con confianza!',
                  style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Plan validado CON condición crítica → aprobado + seguimiento especial (todo verde)
    if ((estadoPlan == 'validado' || estadoPlan == 'modificado') && esCondicionCritica) {
      return Card(
        color: Colors.green.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.medical_services, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensajeCliente,
                  style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determinar tipo de alerta y sus colores
    MaterialColor alertColor;
    IconData alertIcon;
    String alertTitle;

    if (esCondicionCritica) {
      alertColor = Colors.red;
      alertIcon = Icons.local_hospital;
      alertTitle = '⚠️ Validación Requerida';
    } else if (estadoPlan == 'en_revision') {
      alertColor = Colors.orange;
      alertIcon = Icons.pending;
      alertTitle = '🔍 En Revisión';
    } else {
      alertColor = Colors.blue;
      alertIcon = Icons.info;
      alertTitle = '🤖 Plan Provisional';
    }

    return Card(
      color: alertColor.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(alertIcon, color: alertColor.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alertTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: alertColor.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mensajeCliente,
              style: TextStyle(color: alertColor.shade800, height: 1.4),
            ),
            if (esCondicionCritica && onContactarNutricionista != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onContactarNutricionista,
                  icon: const Icon(Icons.phone),
                  label: const Text('Contactar a mi nutricionista'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: alertColor.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            if (estadoPlan == 'provisional_ia' && !esCondicionCritica) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  backgroundColor: alertColor.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(alertColor.shade400),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu nutricionista revisará este plan pronto',
                style: TextStyle(
                  fontSize: 12,
                  color: alertColor.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
