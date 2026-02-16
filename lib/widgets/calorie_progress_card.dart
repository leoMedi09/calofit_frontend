import 'package:flutter/material.dart';

class CalorieProgressMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const CalorieProgressMiniCard({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double consumido = (data['consumido'] ?? 0.0).toDouble();
    final double meta = (data['meta'] ?? 2000.0).toDouble();
    final double restante = (data['restante'] ?? 0.0).toDouble();
    final double quemado = (data['quemado'] ?? 0.0).toDouble();

    double pct = (consumido / meta).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 5,
                  backgroundColor: Colors.blue.shade100.withOpacity(0.3),
                  color: pct > 1.0 ? Colors.red : Colors.blue.shade400,
                ),
              ),
              Text(
                "${(pct * 100).toInt()}%",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RESTANTE: ${restante.toInt()} kcal",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue.shade800,
                  ),
                ),
                Text(
                  "🍽️ Consumido: ${consumido.toInt()} | 🔥 Quemado: ${quemado.toInt()}",
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
