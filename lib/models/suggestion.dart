import 'dart:convert';

class Suggestion {
  final int id;
  final String tipo; // 'comida' or 'ejercicio'
  final String nombre;
  final List<String> ingredientes;
  final List<String> preparacion;
  final String macros;
  final String nota;
  final bool completada;
  final DateTime fechaGuardado;

  Suggestion({
    required this.id,
    required this.tipo,
    required this.nombre,
    required this.ingredientes,
    required this.preparacion,
    required this.macros,
    required this.nota,
    required this.completada,
    required this.fechaGuardado,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] ?? 0,
      tipo: json['tipo'] ?? 'comida',
      nombre: json['nombre'] ?? '',
      ingredientes: json['ingredientes'] != null 
          ? List<String>.from(json['ingredientes']) 
          : [],
      preparacion: json['preparacion'] != null 
          ? List<String>.from(json['preparacion']) 
          : [],
      macros: json['macros'] ?? '',
      nota: json['nota'] ?? '',
      completada: json['completada'] ?? false,
      fechaGuardado: DateTime.parse(json['fecha_guardado'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'nombre': nombre,
      'ingredientes': ingredientes,
      'preparacion': preparacion,
      'macros': macros,
      'nota': nota,
      'completada': completada,
      'fecha_guardado': fechaGuardado.toIso8601String(),
    };
  }
}
