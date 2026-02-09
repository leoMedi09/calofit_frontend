class Dieta {
  final double calorias;
  final double proteinas;
  final double carbohidratos;
  final double grasas;
  final String recomendacion;

  Dieta({
    required this.calorias,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
    required this.recomendacion,
  });

  // Este método convierte el JSON de Python a objetos de Flutter
  factory Dieta.fromJson(Map<String, dynamic> json) {
    return Dieta(
      calorias: json['calorias_totales'].toDouble(),
      proteinas: json['macros']['proteinas_g'].toDouble(),
      carbohidratos: json['macros']['carbohidratos_g'].toDouble(),
      grasas: json['macros']['grasas_g'].toDouble(),
      recomendacion: json['recomendacion'] ?? '',
    );
  }
}