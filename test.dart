import 'dart:convert';
import 'lib/models/assistant_response.dart';

void main() {
  final jsonStr = '''
  {
    "tipo": "ejercicio",
    "nombre": "Press Banca Plano",
    "justificacion": "",
    "ingredientes": [],
    "ejercicios": [
      "4 series de 10 reps"
    ],
    "preparacion": [],
    "tecnica": [
      "Técnica: Baja la barra controladamente hasta el pecho y empuja de vuelta."
    ],
    "instrucciones": [
      "Técnica: Baja la barra controladamente hasta el pecho y empuja de vuelta."
    ],
    "macros": "Cal: 109.8 kcal | Dur: 15 min | MET ~5.0",
    "gasto_calorico_estimado": "Cal: 109.8 kcal | Dur: 15 min | MET ~5.0",
    "nota": ""
  }
  ''';
  final map = jsonDecode(jsonStr);
  final sec = Section.fromJson(map);
  print('ingredientes: ${sec.ingredientes}');
  print('preparacion: ${sec.preparacion}');
}
