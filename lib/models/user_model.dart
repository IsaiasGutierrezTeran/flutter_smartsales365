/// Modelo de usuario según el backend Django
class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? telefono;
  final bool isStaff;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.telefono,
    required this.isStaff,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'],
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      telefono: json['telefono'],
      isStaff: json['is_staff'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'telefono': telefono,
      'is_staff': isStaff,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    }
    return username;
  }
}
