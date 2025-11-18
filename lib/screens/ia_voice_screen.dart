import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../models/user_model.dart';
import '../services/ia_api_service.dart';
import '../services/voice_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Pantalla IA con voz rediseñada - Moderno y limpio
class IAVoiceScreen extends StatefulWidget {
  final User user;

  const IAVoiceScreen({required this.user, super.key});

  @override
  State<IAVoiceScreen> createState() => _IAVoiceScreenState();
}

class _IAVoiceScreenState extends State<IAVoiceScreen>
    with SingleTickerProviderStateMixin {
  late IAApiService _apiService;
  late VoiceService _voiceService;
  late AnimationController _pulseController;

  String _prompt = '';
  String _status = 'Inicializando...';
  bool _isListening = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _resultado;
  String? _errorMessage;

  final List<String> _ejemplos = [
    "Ventas de octubre en PDF",
    "Top 10 productos más vendidos",
    "Clientes activos del último mes",
    "Inventario actual en CSV",
    "Reporte de septiembre",
  ];

  @override
  void initState() {
    super.initState();
    _initServices();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _initServices() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        setState(() {
          _status = 'Error: No hay token';
          _errorMessage = 'Sesión expirada';
        });
        return;
      }

      _apiService = IAApiService(token: token);
      _voiceService = VoiceService();
      await _voiceService.initialize();

      final isHealthy = await _apiService.checkHealth();
      setState(() {
        _status = isHealthy
            ? '✅ Sistema listo para consultas'
            : '⚠️ Servicio no disponible';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;

    setState(() {
      _isListening = true;
      _status = '🎤 Escuchando...';
      _prompt = '';
      _errorMessage = null;
      _resultado = null;
    });

    try {
      await _voiceService.listen(
        onPartialResult: (text) {
          setState(() => _prompt = text);
        },
        onResult: (text) {
          setState(() {
            _prompt = text;
            _isListening = false;
            _status = '⏳ Procesando...';
          });
          _procesarConsulta();
        },
      );

      await Future.delayed(const Duration(seconds: 10));
      if (_isListening) {
        await _voiceService.stop();
        setState(() {
          _isListening = false;
          if (_prompt.isEmpty) {
            _status = '❌ No se capturó texto';
          } else {
            _status = '⏳ Procesando...';
            _procesarConsulta();
          }
        });
      }
    } catch (e) {
      setState(() {
        _isListening = false;
        _status = '❌ Error de micrófono';
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _voiceService.stop();
    setState(() {
      _isListening = false;
      if (_prompt.isEmpty) {
        _status = '❌ Sin texto capturado';
      } else {
        _status = '⏳ Procesando...';
        _procesarConsulta();
      }
    });
  }

  Future<void> _procesarConsulta() async {
    if (_prompt.trim().isEmpty) {
      setState(() {
        _status = '❌ Consulta vacía';
        _errorMessage = 'Di algo primero';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = '⏳ Consultando IA...';
      _resultado = null;
      _errorMessage = null;
    });

    try {
      final promptLower = _prompt.toLowerCase();
      final solicitaPDF = promptLower.contains('pdf');
      final solicitaExcel =
          promptLower.contains('excel') || promptLower.contains('xls');
      final solicitaCSV = promptLower.contains('csv');

      if (solicitaPDF || solicitaExcel || solicitaCSV) {
        String formato = 'pdf';
        if (solicitaExcel) formato = 'excel';
        if (solicitaCSV) formato = 'csv';

        setState(() => _status = '📥 Descargando $formato...');

        final file = await _apiService.descargarReporte(
          prompt: _prompt,
          formato: formato,
        );

        setState(() {
          _status = '✅ Descargado exitosamente';
          _isProcessing = false;
        });

        if (mounted) _showFileDownloadedDialog(file);
      } else {
        final resultado = await _apiService.consultarIA(
          prompt: _prompt,
          formato: 'pantalla',
        );

        setState(() {
          _resultado = resultado;
          final tiempo = resultado['tiempo_ejecucion'] ?? 0;
          _status = '✅ Completado en ${tiempo.toStringAsFixed(2)}s';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error en consulta';
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  void _showFileDownloadedDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ Archivo Descargado'),
        content: Text('Ubicación: ${file.path}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              OpenFile.open(file.path);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.matteBlue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IA + Voz'),
        backgroundColor: AppColors.matteBlue,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Status Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.matteBlue,
                      AppColors.matteBlue700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.matteBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade200,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Micrófono animado
              Center(
                child: GestureDetector(
                  onLongPress: _startListening,
                  onLongPressUp: _stopListening,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                      CurvedAnimation(
                          parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.matteBlue,
                            AppColors.matteBlue700,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.matteBlue.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: _isListening ? 10 : 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isListening ? _stopListening : _startListening,
                          customBorder: const CircleBorder(),
                          child: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: AppColors.white,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                _isListening ? 'Mantén presionado para detener' : 'Toca para hablar',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 32),

              // Texto capturado
              if (_prompt.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.matteBlue.withOpacity(0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu consulta:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _prompt,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Resultados
              if (_resultado != null)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.matteBlue.withOpacity(0.2),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resultado:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _resultado.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Ejemplos
              Text(
                'Ejemplos de consultas:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ejemplos
                    .map(
                      (ejemplo) => Chip(
                        label: Text(ejemplo),
                        backgroundColor: AppColors.matteBlue50,
                        side: const BorderSide(
                          color: AppColors.matteBlue,
                          width: 1,
                        ),
                        labelStyle: const TextStyle(
                          color: AppColors.matteBlue700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
