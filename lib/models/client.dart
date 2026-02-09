class Client {
  final int id;
  final String firstName;
  final String lastNamePaternal;
  final String lastNameMaternal;
  final String email;

  final String flutterUid; // 🔥 Firebase UID
  final DateTime? birthDate;
  final double weight;
  final double height; // en cm
  final String gender; // 'M' | 'F'
  final List<String> medicalConditions;
  final String activityLevel;
  final String goal;

  Client({
    required this.id,
    required this.firstName,
    required this.lastNamePaternal,
    required this.lastNameMaternal,
    required this.email,
    required this.flutterUid,
    this.birthDate,
    required this.weight,
    required this.height,
    required this.gender,
    required this.medicalConditions,
    required this.activityLevel,
    required this.goal,
  });

  String get fullName => '$firstName $lastNamePaternal $lastNameMaternal';

  int get age {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthDate!.year;
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    // ✅ Buscamos en ambas posibles llaves por si acaso
    var conditionsData = json['medical_conditions'] ?? json['medicalConditions'];

    return Client(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastNamePaternal: json['last_name_paternal'] ?? '',
      lastNameMaternal: json['last_name_maternal'] ?? '',
      email: json['email'] ?? '',
      flutterUid: json['flutter_uid'] ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      gender: json['gender'] ?? 'M',
      // ✅ Mejoramos el mapeo para que sea más robusto
      medicalConditions: conditionsData != null
          ? List<String>.from(conditionsData)
          : [],
      activityLevel: json['activity_level'] ?? 'Sedentario',
      goal: json['goal'] ?? 'Mantener peso',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name_paternal': lastNamePaternal,
      'last_name_maternal': lastNameMaternal,
      'email': email,
      'flutter_uid': flutterUid,
      'birth_date': birthDate?.toIso8601String().split('T')[0],
      'weight': weight,
      'height': height,
      'gender': gender,
      'medical_conditions': medicalConditions,
      'activity_level': activityLevel,
      'goal': goal,
    };
  }
}
