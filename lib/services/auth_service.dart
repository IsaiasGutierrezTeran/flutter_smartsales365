import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';

/// Servicio de autenticación para comunicarse con el backend Django
class AuthService {
  // URL del servidor SmartSales365 en producción
  static const String baseUrl = 'https://smartsales365.duckdns.org';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Headers básicos para las peticiones
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Headers con autenticación (token)
  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {..._headers, 'Authorization': 'Token $token'};
  }

  /// Login con username y password
  /// POST /api/usuarios/token/
  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      print('🔵 LOGIN - Intentando conectar a: $baseUrl/api/usuarios/token/');
      print('🔵 LOGIN - Usuario: $username');

      // Limpiar token previo
      await logout();

      http.Response response;
      
      try {
        // Intento 1: JSON (método preferido)
        response = await http.post(
          Uri.parse('$baseUrl/api/usuarios/token/'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': password}),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('⏱️ Tiempo de espera agotado. Verifica tu conexión.');
          },
        );
        
        print('🔵 LOGIN - Status Code: ${response.statusCode}');
        
      } catch (e) {
        print('⚠️ LOGIN - Error con JSON, intentando form-urlencoded...');
        
        // Intento 2: Form-urlencoded (fallback como en React)
        response = await http.post(
          Uri.parse('$baseUrl/api/usuarios/token/'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: 'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('⏱️ Tiempo de espera agotado. Verifica tu conexión.');
          },
        );
        
        print('🔵 LOGIN - Status Code (form): ${response.statusCode}');
      }

      print('🔵 LOGIN - Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final token = data['token'];

        // Guardar token
        await _saveToken(token);

        // Obtener perfil del usuario
        print('🔵 LOGIN - Obteniendo perfil del usuario...');
        final user = await getProfile();

        print('✅ LOGIN - Exitoso para: ${user.username}');
        return LoginResponse(token: token, user: user);
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        print('❌ LOGIN - Error: ${error['detail'] ?? error['non_field_errors']}');
        throw Exception(error['detail'] ?? error['non_field_errors']?.toString() ?? 'Credenciales inválidas');
      } else {
        throw Exception('Error del servidor (${response.statusCode})');
      }
    } catch (e) {
      print('❌ LOGIN - Excepción: $e');

      // Manejo específico de errores CORS en Flutter Web
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException')) {
        throw Exception(
          '🌐 Error de CORS en Flutter Web.\n\n'
          'Soluciones:\n'
          '1. Prueba la app en Android/iOS (no tienen CORS)\n'
          '2. Verifica que el backend tenga CORS configurado\n'
          '3. Usa un proxy o extensión de CORS en Chrome'
        );
      }

      // Error de conexión
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
          '❌ No se puede conectar al servidor en $baseUrl.\n'
          'Verifica:\n'
          '1. Tu conexión a internet\n'
          '2. Que el servidor esté corriendo\n'
          '3. La URL del servidor'
        );
      }

      // Error de timeout
      if (e.toString().contains('⏱️')) {
        rethrow;
      }

      throw Exception('Error de conexión: $e');
    }
  }

  /// Obtener perfil del usuario autenticado
  /// GET /api/usuarios/me/
  Future<User> getProfile() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/usuarios/me/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final user = User.fromJson(data);
        await _saveUser(user);
        return user;
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else {
        throw Exception('Error al obtener perfil');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Cerrar sesión (eliminar token y datos locales)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Verificar si hay sesión activa
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Obtener token guardado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Obtener usuario guardado
  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  /// Guardar token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Guardar usuario
  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }
}
