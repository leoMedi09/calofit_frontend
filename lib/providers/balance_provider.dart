import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../models/suggestion.dart';
import '../services/api_service.dart';

class BalanceProvider with ChangeNotifier {
  DailySummary? _dailySummary;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  DailySummary? get dailySummary => _dailySummary;
  bool get isLoading => _isLoading;

  Map<String, dynamic>? _fullBalanceData;
  Map<String, dynamic>? get fullBalanceData => _fullBalanceData;

  List<Suggestion> _suggestions = [];
  List<Suggestion> get suggestions => _suggestions;
  bool _isSuggestionsLoading = false;
  bool get isSuggestionsLoading => _isSuggestionsLoading;

  // Helper interno de casteo seguro
  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  void updateFromAssistant(Map<String, dynamic> dataCientifica) {
    if (dataCientifica.isEmpty) return;

    // Actualizar DailySummary (Preservar macros si no vienen en la actualización parcial)
    _dailySummary = DailySummary(
      calorias: _toDouble(dataCientifica['consumido'] ?? dataCientifica['calorias'] ?? _dailySummary?.calorias),
      proteinas: _toDouble(dataCientifica['proteinas'] ?? _dailySummary?.proteinas),
      carbohidratos: _toDouble(dataCientifica['carbohidratos'] ?? _dailySummary?.carbohidratos),
      grasas: _toDouble(dataCientifica['grasas'] ?? _dailySummary?.grasas),
      gastoMetabolicoBasal: _dailySummary?.gastoMetabolicoBasal ?? 0.0,
      caloriasQuemadas: _toDouble(dataCientifica['quemado'] ?? _dailySummary?.caloriasQuemadas ?? 0.0),
      imcActual: _dailySummary?.imcActual ?? 0.0,
      aiInsight: _dailySummary?.aiInsight ?? "",
      planObjetivo: _dailySummary?.planObjetivo,
    );
    
    // Si tenemos fullData, intentamos actualizar también el resumen dentro de él para consistencia inmediata
    if (_fullBalanceData != null && _fullBalanceData!.containsKey('resumen')) {
       var resumen = _fullBalanceData!['resumen'];
       resumen['calorias_consumidas'] = _dailySummary!.calorias;
       resumen['calorias_quemadas'] = _dailySummary!.caloriasQuemadas;
       _fullBalanceData!['resumen'] = resumen;
    }
    
    notifyListeners();
  }

  Future<void> fetchFullBalance(String token, {String? fecha}) async {
    try {
      final data = await _apiService.getMiBalance(token, fecha: fecha);
      _fullBalanceData = data;
      
      // ✅ FIX: Solo actualilzamos el resumen de HOY (Dashboard) si NO estamos viajando en el tiempo
      if (data['resumen'] != null && fecha == null) {
        final res = data['resumen'];
        // ✅ FIX (v60): Mapear macros reales desde el servidor, NO resetear a 0.0
        _dailySummary = DailySummary(
          calorias: _toDouble(res['calorias_consumidas']),
          proteinas: _toDouble(res['proteinas_g']), 
          carbohidratos: _toDouble(res['carbohidratos_g']),
          grasas: _toDouble(res['grasas_g']),
          gastoMetabolicoBasal: _dailySummary?.gastoMetabolicoBasal ?? 0.0,
          caloriasQuemadas: _toDouble(res['calorias_quemadas']),
          imcActual: _dailySummary?.imcActual ?? 0.0,
          aiInsight: _dailySummary?.aiInsight ?? "",
          planObjetivo: _dailySummary?.planObjetivo
        );
      }
      notifyListeners();
    } catch (e) {
      print('Error loading full balance: $e');
      rethrow;
    }
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

  // ============ RECETARIO (SUGERENCIAS) ============

  Future<void> fetchSuggestions(String token) async {
    _isSuggestionsLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _apiService.listarSugerencias(token);
      _suggestions = data.map((item) => Suggestion.fromJson(item)).toList();
    } catch (e) {
      print('Error loading suggestions: $e');
    } finally {
      _isSuggestionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSuggestion(int id, String token) async {
    try {
      await _apiService.eliminarSugerencia(id, token);
      _suggestions.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting suggestion: $e');
      rethrow;
    }
  }
}
