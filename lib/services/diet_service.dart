import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dieta.dart';

class DietService {
  // CAMBIA ESTO: Usa la IP de tu PC, no pongas localhost
  static const String baseUrl = "http://192.168.1.100:8000";

  static Future<Dieta?> obtenerDieta(String uid) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/clientes/por-uid/$uid'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Extraemos solo la parte de 'dieta_automatica' del JSON
        return Dieta.fromJson(data['dieta_automatica']);
      }
      return null;
    } catch (e) {
      print("Error conectando al backend: $e");
      return null;
    }
  }
}