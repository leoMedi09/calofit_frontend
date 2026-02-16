import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/api_service.dart';

class BalanceProvider with ChangeNotifier {
  DailySummary? _dailySummary;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  DailySummary? get dailySummary => _dailySummary;
  bool get isLoading => _isLoading;

  void updateFromAssistant(Map<String, dynamic> dataCientifica) {
    if (dataCientifica.isEmpty) return;

    // El backend envía el progreso en data_cientifica
    // Mapeamos a DailySummary
    _dailySummary = DailySummary(
      calorias: (dataCientifica['consumido'] ?? dataCientifica['calorias'] ?? _dailySummary?.calorias ?? 0).toDouble(),
      proteinas: (dataCientifica['proteinas'] ?? _dailySummary?.proteinas ?? 0).toDouble(),
      carbohidratos: (dataCientifica['carbohidratos'] ?? _dailySummary?.carbohidratos ?? 0).toDouble(),
      grasas: (dataCientifica['grasas'] ?? _dailySummary?.grasas ?? 0).toDouble(),
      gastoEstimado: _dailySummary?.gastoEstimado ?? 0,
      imcActual: _dailySummary?.imcActual ?? 0,
      aiInsight: _dailySummary?.aiInsight ?? "",
      planObjetivo: _dailySummary?.planObjetivo, // Mantener el plan si ya existe
    );
    
    notifyListeners();
  }

  Future<void> loadDailySummary(int clientId, String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.getDailySummary(clientId, token);
      _dailySummary = DailySummary.fromJson(data);
    } catch (e) {
      print('Error loading summary in Provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSummary(DailySummary summary) {
    _dailySummary = summary;
    notifyListeners();
  }
}
