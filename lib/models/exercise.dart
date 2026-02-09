class Exercise {
  final int id;
  final String name;
  final String description;
  // Campos adicionales: calorías, duración, etc.

  Exercise({required this.id, required this.name, required this.description});

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}