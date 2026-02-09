class NutritionPlan {
  final int id;
  final int clientId;
  final String details;
  // Campos adicionales: calorías diarias, macronutrientes, etc.

  NutritionPlan({required this.id, required this.clientId, required this.details});

  factory NutritionPlan.fromJson(Map<String, dynamic> json) {
    return NutritionPlan(
      id: json['id'],
      clientId: json['client_id'],
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'details': details,
    };
  }
}