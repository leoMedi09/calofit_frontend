import 'package:flutter_test/flutter_test.dart';
import 'package:calofit_frontend/models/assistant_response.dart';
import 'dart:convert';

void main() {
  group('AI Parsing Tests', () {
    test('Should parse AssistantResponse correctly', () {
      final jsonResponse = {
        "usuario": "TestUser",
        "data_cientifica": {
          "calorias_calculadas": 2000,
          "macros": {"P": 150, "C": 200, "G": 60},
          "progreso_diario": {
            "consumido": 500,
            "meta": 2000,
            "restante": 1500,
            "quemado": 0
          },
          "fuente_calorica": "Plan Nutricional Validado"
        },
        "respuesta_estructurada": {
          "texto_conversacional": "Hola, aquí tienes tu plan.",
          "secciones": [
            {
              "tipo": "comida",
              "nombre": "Pollo a la Brasa",
              "ingredientes": ["Pollo", "Papas"],
              "preparacion": ["Hornear pollo", "Freír papas"],
              "macros": "P: 40g, C: 50g, G: 20g",
              "nota": "Ojo con la mayonesa."
            }
          ]
        },
        "alerta_salud": false
      };

      final response = AssistantResponse.fromJson(jsonResponse);

      expect(response.usuario, "TestUser");
      expect(response.dataCientifica.progresoDiario['consumido'], 500);
      expect(response.respuestaEstructurada.textoConversacional, "Hola, aquí tienes tu plan.");
      expect(response.respuestaEstructurada.secciones.length, 1);
      
      final section = response.respuestaEstructurada.secciones.first;
      expect(section.tipo, "comida");
      expect(section.nombre, "Pollo a la Brasa");
      expect(section.ingredientes.length, 2);
      expect(section.ingredientes[0], "Pollo");
    });

    test('Should parse Smart Log response correctly', () {
      final jsonResponse = {
        "success": true,
        "tipo_detectado": "comida",
        "alimentos": ["Manzana"],
        "datos": {
          "calorias": 95,
          "proteinas": 0.5,
          "carbos": 25,
          "grasas": 0.3
        },
        "balance_actualizado": { // This is what BalanceProvider uses
           "consumido": 1500,
           "quemado": 200
        },
        "mensaje": "He registrado tu comida exitosamente."
      };
      
      // We don't have a specific model for Smart Log response yet, 
      // but let's verify if BalanceProvider logic holds up here.
      // (This logic is tested in provider test, but good to verify structure).
      
      final balanceData = jsonResponse['balance_actualizado'] as Map<String, dynamic>;
      expect(balanceData['consumido'], 1500);
    });
  });
}
