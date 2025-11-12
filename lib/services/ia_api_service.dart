import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Servicio de API para consultas de IA
/// Basado en la documentación del backend Django
class IAApiService {
  static const String baseUrl = 'https://smartsales365.duckdns.org';

  final String token;

  IAApiService({required this.token});

  Map<String, String> get _headers => {
    'Authorization': 'Token $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Health check del servicio de IA
  /// GET /api/ia/health/
  Future<bool> checkHealth() async {
    try {
      print('🔵 IA - Health check...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/ia/health/'),
        headers: _headers,
      );
      print('🔵 IA - Health: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ IA - Health check falló: $e');
      return false;
    }
  }

  /// Consulta de IA - Formato pantalla (JSON)
  /// POST /api/ia/consulta/
  Future<Map<String, dynamic>> consultarIA({
    required String prompt,
    String? formato,
  }) async {
    try {
      print('🔵 IA - Consultando: $prompt');
      print('🔵 IA - Formato: ${formato ?? "auto-detectar"}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/ia/consulta/'),
        headers: _headers,
        body: jsonEncode({
          'prompt': prompt,
          if (formato != null) 'formato': formato,
        }),
      );

      print('🔵 IA - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('✅ IA - Consulta exitosa');
        return data;
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        print('❌ IA - Error: ${error['detail']}');
        throw Exception(error['detail'] ?? 'Error desconocido');
      }
    } catch (e) {
      print('❌ IA - Excepción: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          '❌ No se puede conectar al servidor. Verifica que Django esté corriendo.',
        );
      }
      rethrow;
    }
  }

  /// Descargar reporte (PDF/Excel/CSV)
  /// POST /api/ia/consulta/ con formato específico
  Future<File> descargarReporte({
    required String prompt,
    required String formato, // 'pdf', 'excel', 'csv'
  }) async {
    try {
      print('🔵 IA - Descargando reporte: $formato');
      print('🔵 IA - Prompt: $prompt');

      final response = await http.post(
        Uri.parse('$baseUrl/api/ia/consulta/'),
        headers: _headers,
        body: jsonEncode({'prompt': prompt, 'formato': formato}),
      );

      print('🔵 IA - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Extraer nombre del archivo del header
        final contentDisposition = response.headers['content-disposition'];
        String filename =
            'reporte_${DateTime.now().millisecondsSinceEpoch}.$formato';

        if (contentDisposition != null) {
          final regex = RegExp(r'filename="(.+)"');
          final match = regex.firstMatch(contentDisposition);
          if (match != null) {
            filename = match.group(1)!;
          }
        }

        // Guardar archivo
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);

        print('✅ IA - Archivo guardado: ${file.path}');
        return file;
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        print('❌ IA - Error: ${error['detail']}');
        throw Exception(error['detail'] ?? 'Error al descargar reporte');
      }
    } catch (e) {
      print('❌ IA - Excepción en descarga: $e');
      rethrow;
    }
  }
}
