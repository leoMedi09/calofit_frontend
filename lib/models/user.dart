class User {
  final int id;
  final String firstName;
  final String lastNamePaternal;
  final String lastNameMaternal;
  final String email;
  final String roleName;
  final bool isActive;
  final int? pacientesCount;
  final String? profilePictureUrl;

  User({
    required this.id, 
    required this.firstName, 
    required this.lastNamePaternal,
    required this.lastNameMaternal,
    required this.email,
    required this.roleName,
    this.isActive = true,
    this.pacientesCount,
    this.profilePictureUrl,
  });

  String get fullName => '$firstName $lastNamePaternal $lastNameMaternal';

  bool get isNutri  => roleName.toLowerCase().contains('nutri');
  bool get isAdmin  => roleName.toLowerCase().contains('admin');
  bool get isCoach  => roleName.toLowerCase().contains('coach') ||
                       roleName.toLowerCase().contains('train') ||
                       roleName.toLowerCase().contains('entrenador');

  String get roleDisplayLabel {
    if (isNutri)  return 'NUTRI';
    if (isAdmin)  return 'ADMIN';
    if (isCoach)  return 'ENTRENADOR';
    return roleName.toUpperCase();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastNamePaternal: json['last_name_paternal'] ?? '',
      lastNameMaternal: json['last_name_maternal'] ?? '',
      email: json['email'] ?? '',
      roleName: json['role_name'] ?? 'staff',
      isActive: json['is_active'] ?? true,
      pacientesCount: json['pacientes_count'],
      profilePictureUrl: json['profile_picture_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name_paternal': lastNamePaternal,
      'last_name_maternal': lastNameMaternal,
      'email': email,
      'role_name': roleName,
      'is_active': isActive,
      'pacientes_count': pacientesCount,
      'profile_picture_url': profilePictureUrl,
    };
  }
}