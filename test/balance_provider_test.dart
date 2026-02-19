import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:calofit_frontend/providers/balance_provider.dart';
import 'package:calofit_frontend/models/assistant_response.dart';

void main() {
  group('Balance Provider Tests', () {
    test('updateFromAssistant should update summary with backend response', () {
      final provider = BalanceProvider();
      
      // Initial state
      expect(provider.dailySummary, isNull);
      
      // Simulate backend response from "Smart Log" (which returns updated totals)
      final backendResponse = {
        "consumido": 1500,
        "quemado": 200,
        "proteinas": 100,
        "carbohidratos": 150,
        "grasas": 50
      };
      
      provider.updateFromAssistant(backendResponse);
      
      expect(provider.dailySummary, isNotNull);
      expect(provider.dailySummary!.calorias, 1500);
      expect(provider.dailySummary!.quemado, 200); // Verify if quemado is updated correctly in provider
      expect(provider.dailySummary!.proteinas, 100);
    });

    test('updateFromAssistant should handle partial updates', () {
      final provider = BalanceProvider();
      
      // Simulate first update
      provider.updateFromAssistant({
        "consumido": 1000, 
        "proteinas": 50
      });
      
      expect(provider.dailySummary!.calorias, 1000);
      expect(provider.dailySummary!.proteinas, 50);
      
      // Simulate second update with ONLY calories (e.g. from a different endpoint)
      // If passing null for proteins, it should keep previous value
      provider.updateFromAssistant({
        "consumido": 1200
      });
      
      expect(provider.dailySummary!.calorias, 1200);
      expect(provider.dailySummary!.proteinas, 50); // Should remain 50
    });
  });
}
