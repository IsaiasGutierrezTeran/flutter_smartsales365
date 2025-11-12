import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../models/user_model.dart';
import '../services/ia_api_service.dart';
import '../services/voice_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Pantalla principal de consulta IA con reconocimiento de voz
/// Implementación completa según documentación del backend
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

  // Ejemplos de prompts
  final List<String> _ejemplos = [
    "Ventas de octubre en PDF",
    "Top 10 productos más vendidos en Excel",
    "Clientes activos del último mes",
    "Inventario actual en CSV",
    "Ventas de septiembre agrupado por producto",
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

  /// Inicializar servicios
  Future<void> _initServices() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        setState(() {
          _status = 'Error: No hay token de autenticación';
          _errorMessage = 'Sesión expirada';
        });
        return;
      }

      _apiService = IAApiService(token: token);
      _voiceService = VoiceService();

      // Inicializar voz
      await _voiceService.initialize();

      // Verificar salud del servicio
      final isHealthy = await _apiService.checkHealth();

      setState(() {
        _status = isHealthy
            ? '✅ Listo - Presiona el micrófono para hablar'
            : '⚠️ Servicio de IA no disponible';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _errorMessage = e.toString();
      });
    }
  }

  /// Iniciar escucha de voz
  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;

    setState(() {
      _isListening = true;
      _status = '🎤 Escuchando... Habla ahora';
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
            _status = '🔍 Procesando consulta...';
          });
          _procesarConsulta();
        },
      );

      // Auto-stop después de 10 segundos
      await Future.delayed(const Duration(seconds: 10));
      if (_isListening) {
        await _voiceService.stop();
        setState(() {
          _isListening = false;
          if (_prompt.isEmpty) {
            _status = '❌ No se capturó ningún texto';
            _errorMessage = 'Intenta de nuevo';
          } else {
            _status = '🔍 Procesando consulta...';
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

  /// Detener escucha manual
  Future<void> _stopListening() async {
    if (!_isListening) return;

    await _voiceService.stop();
    setState(() {
      _isListening = false;
      if (_prompt.isEmpty) {
        _status = '❌ No se capturó ningún texto';
      } else {
        _status = '🔍 Procesando consulta...';
        _procesarConsulta();
      }
    });
  }

  /// Procesar consulta con IA
  Future<void> _procesarConsulta() async {
    if (_prompt.trim().isEmpty) {
      setState(() {
        _status = '❌ Prompt vacío';
        _errorMessage = 'Escribe o di algo primero';
      });
      return;
    }

    if (_prompt.trim().length < 10) {
      setState(() {
        _status = '⚠️ Consulta muy corta';
        _errorMessage = 'Sé más específico (mínimo 10 caracteres)';
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
      // Detectar si pide archivo o pantalla
      final promptLower = _prompt.toLowerCase();
      final solicitaPDF = promptLower.contains('pdf');
      final solicitaExcel =
          promptLower.contains('excel') || promptLower.contains('xls');
      final solicitaCSV = promptLower.contains('csv');

      if (solicitaPDF || solicitaExcel || solicitaCSV) {
        // Descargar archivo
        String formato = 'pdf';
        if (solicitaExcel) formato = 'excel';
        if (solicitaCSV) formato = 'csv';

        setState(() => _status = '📥 Descargando $formato...');

        final file = await _apiService.descargarReporte(
          prompt: _prompt,
          formato: formato,
        );

        setState(() {
          _status = '✅ Reporte descargado exitosamente';
          _isProcessing = false;
        });

        // Mostrar diálogo con opción de abrir
        if (mounted) _showFileDownloadedDialog(file);
      } else {
        // Mostrar en pantalla
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
        _status = '❌ Error en la consulta';
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  /// Mostrar diálogo de archivo descargado
  void _showFileDownloadedDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Reporte Generado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('El reporte se ha generado correctamente.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await OpenFile.open(file.path);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir Archivo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.matteBlue700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo de entrada manual
  void _showManualInputDialog() {
    final controller = TextEditingController(text: _prompt);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escribe tu consulta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ej: Ventas de octubre en PDF',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mínimo 10 caracteres',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _prompt = controller.text);
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _procesarConsulta();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.matteBlue700,
            ),
            child: const Text('Consultar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mic_rounded, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Consulta IA con Voz',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
  backgroundColor: AppColors.matteBlue700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Ayuda',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.matteBlue700, AppColors.matteBlue50],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header con estado
              _buildStatusCard(),

              // Contenido principal
              Expanded(
                child: _resultado != null
                    ? _buildResultadoView()
                    : _buildMainView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de estado mejorado
  Widget _buildStatusCard() {
    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.info_outline_rounded;
    Color bgColor = Colors.blue.shade50;

    if (_isListening) {
      statusColor = Colors.red;
      statusIcon = Icons.mic_rounded;
      bgColor = Colors.red.shade50;
    } else if (_isProcessing) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_bottom_rounded;
      bgColor = Colors.orange.shade50;
    } else if (_errorMessage != null) {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.error_outline_rounded;
      bgColor = Colors.red.shade50;
    } else if (_status.contains('✅')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
      bgColor = Colors.green.shade50;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, bgColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono animado
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(
                        _isListening ? 0.3 + (_pulseController.value * 0.4) : 0.2,
                      ),
                      statusColor.withOpacity(
                        _isListening ? 0.2 + (_pulseController.value * 0.3) : 0.15,
                      ),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 10 + (_pulseController.value * 5),
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(statusIcon, color: statusColor, size: 30),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vista principal (cuando no hay resultados)
  Widget _buildMainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt capturado
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tu consulta:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _prompt.isEmpty
                          ? 'Presiona el micrófono y habla, o escribe tu consulta...'
                          : _prompt,
                      style: TextStyle(
                        fontSize: 15,
                        color: _prompt.isEmpty
                            ? Colors.grey.shade600
                            : Colors.black87,
                        fontStyle: _prompt.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botón de micrófono grande
          _buildMicrophoneButton(),

          const SizedBox(height: 16),

          // Botón de escritura manual mejorado
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.matteBlue300,
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isProcessing || _isListening
                    ? null
                    : _showManualInputDialog,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_rounded,
                        color: AppColors.matteBlue600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'O escribe tu consulta',
                        style: TextStyle(
                          color: AppColors.matteBlue600,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Ejemplos de prompts
          Text(
            'Ejemplos de consultas:',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._ejemplos.map((ejemplo) => _buildEjemploChip(ejemplo)),
        ],
      ),
    );
  }

  /// Botón de micrófono principal mejorado
  Widget _buildMicrophoneButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final isActive = _isListening;
  final baseColor = isActive ? Colors.red : AppColors.matteBlue;
        final glowIntensity = 0.4 + (_pulseController.value * 0.3);

        return GestureDetector(
          onTap: _isProcessing
              ? null
              : (_isListening ? _stopListening : _startListening),
          child: Container(
            height: 160,
            width: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Glow externo
                BoxShadow(
                  color: baseColor.withOpacity(glowIntensity),
                  blurRadius: 30 + (_pulseController.value * 20),
                  spreadRadius: 10,
                ),
                // Sombra base
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [Colors.red.shade400, Colors.red.shade700]
                      : [AppColors.matteBlue400, AppColors.matteBlue700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icono de micrófono con animación
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 1.0,
                        end: isActive ? 1.2 : 1.0,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Icon(
                            isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                            size: 70,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Texto con animación
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isActive ? 15 : 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      child: Text(
                        isActive ? '🎤 Escuchando...' : 'Presiona para hablar',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Chip de ejemplo clicable
  Widget _buildEjemploChip(String ejemplo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isProcessing || _isListening
            ? null
            : () {
                setState(() => _prompt = ejemplo);
                _procesarConsulta();
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: AppColors.matteBlue700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(ejemplo, style: const TextStyle(fontSize: 14)),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista de resultados
  Widget _buildResultadoView() {
    final resultado = _resultado!['resultado'];
    final interpretacion = _resultado!['interpretacion'];
    final datos = resultado['datos'] as List;
    final columnas = resultado['columnas'] as List;

    return Column(
      children: [
        // Header de resultados
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: AppColors.matteBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resultados: ${interpretacion['tipo_reporte']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _resultado = null;
                        _prompt = '';
                      });
                    },
                  ),
                ],
              ),
              if (interpretacion['fecha_inicio'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Período: ${_formatDate(interpretacion['fecha_inicio'])} - ${_formatDate(interpretacion['fecha_fin'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text('${datos.length} registros'),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(color: Colors.blue.shade700),
                  ),
                  if (interpretacion['agrupar_por'] != null)
                    Chip(
                      label: Text(
                        'Agrupado por: ${interpretacion['agrupar_por'].join(", ")}',
                      ),
                      backgroundColor: AppColors.matteBlue50,
                      labelStyle: TextStyle(color: AppColors.matteBlue700),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Tabla de datos
        Expanded(
          child: datos.isEmpty
              ? const Center(child: Text('Sin datos'))
              : Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.matteBlue50,
                        ),
                        columns: columnas
                            .map(
                              (col) => DataColumn(
                                label: Text(
                                  col.toString().toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.matteBlue700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        rows: datos.map((row) {
                          return DataRow(
                            cells: columnas.map((col) {
                              final value = row[col];
                              return DataCell(
                                Text(
                                  value?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),

        // Botón de nueva consulta
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _resultado = null;
                _prompt = '';
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Nueva Consulta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Formatear fecha
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Mostrar diálogo de ayuda
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: AppColors.matteBlue),
            SizedBox(width: 12),
            Text('Ayuda'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tipos de reporte:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...[
                '• Ventas: "ventas", "compras", "pedidos"',
                '• Clientes: "clientes"',
                '• Productos: "productos"',
                '• Inventario: "inventario", "stock"',
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(e),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Formatos disponibles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...[
                '• PDF: incluye "pdf" en tu consulta',
                '• Excel: incluye "excel"',
                '• CSV: incluye "csv"',
                '• Pantalla: no menciones formato',
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(e),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fechas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...[
                '• "de octubre"',
                '• "del 01/10/2024 al 31/10/2024"',
                '• "del último mes"',
                '• "de este mes"',
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(e),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
