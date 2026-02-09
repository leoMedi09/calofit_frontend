class User {
  final int id;
  final String firstName;
  final String lastNamePaternal;
  final String lastNameMaternal;
  final String email;
  final String roleName;
  final bool isActive;

  User({
    required this.id, 
    required this.firstName, 
    required this.lastNamePaternal,
    required this.lastNameMaternal,
    required this.email,
    required this.roleName,
    this.isActive = true,
  });

  String get fullName => '$firstName $lastNamePaternal $lastNameMaternal';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastNamePaternal: json['last_name_paternal'] ?? '',
      lastNameMaternal: json['last_name_maternal'] ?? '',
      email: json['email'] ?? '',
      roleName: json['role_name'] ?? 'staff',
      isActive: json['is_active'] ?? true,
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
    };
  }
}