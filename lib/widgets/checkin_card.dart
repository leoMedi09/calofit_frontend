import 'package:flutter/material.dart';

class CheckInCard extends StatelessWidget {
  final int precisionScore; // 0 a 100
  final bool isNeeded;
  final int daysUntilCheckin; // 0 = no programado
  final VoidCallback onTap;

  const CheckInCard({
    super.key,
    required this.precisionScore,
    required this.isNeeded,
    this.daysUntilCheckin = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = precisionScore > 70 
        ? Colors.green 
        : (precisionScore > 30 ? Colors.orange : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF283593), const Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CALIBRACIÓN DE IA',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              'Check-in Mensual',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isNeeded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HOY',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Precisión del Plan',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '$precisionScore%',
                                style: TextStyle(color: statusColor, fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: precisionScore / 100,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 32),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isNeeded
                      ? '⚠️ Requiere datos para la próxima semana. ¡Actualiza ahora!'
                      : precisionScore >= 100
                          ? '✅ IA operando al máximo nivel de precisión.'
                          : daysUntilCheckin > 0
                              ? '📅 Próxima calibración en $daysUntilCheckin días — toca para adelantar.'
                              : '📅 Actualiza tus medidas para mejorar la precisión del plan.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
