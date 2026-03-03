class LoginRequest {
  final String email;
  final String password;
  final bool rememberMe;
  final String firebaseUid;
  final String userType; // 'client' o 'staff'

  LoginRequest({
    required this.email,
    required this.password,
    required this.firebaseUid,
    required this.userType,
    this.rememberMe = false
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'remember_me': rememberMe,
      'firebase_uid': firebaseUid,
      'user_type': userType
    };
  }
}

class LoginResponse {
  final String? token;
  final String? userType;
  final String? userRole;
  final String? userName;
  final String? userEmail;
  final int? userId;
  final String? firebaseUid;
  final String? profilePictureUrl; // ✅ Añadido

  LoginResponse({
    this.token,
    this.userType,
    this.userRole,
    this.userName,
    this.userEmail,
    this.userId,
    this.firebaseUid,
    this.profilePictureUrl,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final userInfo = json['user_info'] as Map<String, dynamic>?;

    return LoginResponse(
      token: json['access_token'] as String?,
      firebaseUid: json['firebase_uid'] as String? ?? json['flutter_uid'] as String?,
      userType: userInfo?['type'] as String?,
      userRole: userInfo?['role'] as String?,
      userName: userInfo?['name'] as String? ?? userInfo?['first_name'] as String?,
      userEmail: userInfo?['email'] as String?,
      userId: userInfo?['id'] as int?,
      profilePictureUrl: userInfo?['profile_picture_url'] as String?,
    );
  }
}

class ClientRegisterRequest {
  final String firstName;
  final String lastNamePaternal;
  final String lastNameMaternal;
  final String email;
  final String password;
  final double weight;
  final double height;
  final String medicalConditionsText; // Para el TextField
  final int assignedCoachId;
  final int assignedNutriId;
  final String activityLevel;
  final String goal;
  final String birthDate; // Formato YYYY-MM-DD
  final String flutterUid; // UID de Firebase
  final String gender;    // Masculino/Femenino

  ClientRegisterRequest({
    required this.firstName,
    required this.lastNamePaternal,
    required this.lastNameMaternal,
    required this.email,
    required this.password,
    required this.weight,
    required this.height,
    required this.medicalConditionsText,
    this.assignedCoachId = 1,
    this.assignedNutriId = 1,
    required this.activityLevel,
    required this.goal,
    required this.birthDate,
    required this.flutterUid,
    required this.gender,
  });

  Map<String, dynamic> toJson() {
    // Convertir string a lista (dividir por comas)
    List<String> medicalConditionsList = medicalConditionsText.isEmpty
        ? []
        : medicalConditionsText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return {
      'first_name': firstName,
      'last_name_paternal': lastNamePaternal,
      'last_name_maternal': lastNameMaternal,
      'email': email,
      'password': password,
      'weight': weight,
      'height': height,
      'medical_conditions': medicalConditionsList, // ✅ Ahora es lista
      'assigned_coach_id': assignedCoachId,
      'assigned_nutri_id': assignedNutriId,
      'activity_level': activityLevel,
      'goal': goal,
      'birth_date': birthDate,
      'flutter_uid': flutterUid,
      'gender': gender,
    };
  }

  String get fullName => '$firstName $lastNamePaternal $lastNameMaternal';
}

