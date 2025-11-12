import 'user_model.dart';

/// Respuesta del endpoint /api/usuarios/token/ (login antiguo)
/// y /api/usuarios/login/ (si existe)
class LoginResponse {
  final String token;
  final User user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(token: json['token'], user: User.fromJson(json));
  }
}
