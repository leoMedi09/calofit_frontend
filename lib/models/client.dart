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
  final String workoutType;     // 🆕 Para ML Random Forest
  final double sessionDuration;  // 🆕 Para ML Random Forest (en horas)
  final String? profilePictureUrl;
  final int? assignedNutriId;
  final bool isProfileComplete;
  final DateTime? termsAcceptedAt;

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
    this.workoutType = 'Cardio',
    this.sessionDuration = 1.0,
    this.profilePictureUrl,
    this.assignedNutriId,
    this.isProfileComplete = false,
    this.termsAcceptedAt,
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
      workoutType: json['workout_type'] ?? 'Cardio',
      sessionDuration: (json['session_duration'] as num?)?.toDouble() ?? 1.0,
      profilePictureUrl: json['profile_picture_url'] ?? json['profilePictureUrl'],
      assignedNutriId: json['assigned_nutri_id'],
      isProfileComplete: json['is_profile_complete'] ?? false,
      termsAcceptedAt: json['terms_accepted_at'] != null
          ? DateTime.parse(json['terms_accepted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
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
      'workout_type': workoutType,
      'session_duration': sessionDuration,
      'profile_picture_url': profilePictureUrl,
      'assigned_nutri_id': assignedNutriId,
      'is_profile_complete': isProfileComplete,
    };
    // Solo se envía si hay un valor real: evita que ediciones de perfil
    // posteriores (que no conocen este campo) borren la aceptación ya guardada.
    if (termsAcceptedAt != null) {
      map['terms_accepted_at'] = termsAcceptedAt!.toIso8601String();
    }
    return map;
  }
}
