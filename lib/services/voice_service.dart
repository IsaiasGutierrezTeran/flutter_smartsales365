import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio de reconocimiento de voz
/// Usa speech_to_text para capturar comandos en español
class VoiceService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  /// Inicializar servicio de voz
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    print('🔵 VOZ - Inicializando...');

    // Solicitar permiso de micrófono
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print('❌ VOZ - Permiso denegado');
      throw Exception('Permiso de micrófono denegado');
    }

    // Inicializar speech_to_text
    _isInitialized = await _speech.initialize(
      onError: (error) => print('❌ VOZ - Error: $error'),
      onStatus: (status) => print('🔵 VOZ - Estado: $status'),
    );

    print(
      _isInitialized ? '✅ VOZ - Inicializado' : '❌ VOZ - Fallo al inicializar',
    );
    return _isInitialized;
  }

  /// Escuchar comando de voz
  Future<String?> listen({
    required Function(String) onResult,
    Function(String)? onPartialResult,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      throw Exception('No se pudo inicializar el reconocimiento de voz');
    }

    print('🔵 VOZ - Escuchando...');
    String? finalResult;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          finalResult = result.recognizedWords;
          print('✅ VOZ - Capturado: $finalResult');
          onResult(result.recognizedWords);
        } else if (onPartialResult != null) {
          onPartialResult(result.recognizedWords);
        }
      },
      localeId: 'es_ES', // Español
      listenMode: ListenMode.confirmation,
    );

    return finalResult;
  }

  /// Detener escucha
  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
      print('🔵 VOZ - Detenido');
    }
  }

  /// Verificar si está escuchando
  bool get isListening => _speech.isListening;

  /// Verificar disponibilidad
  bool get isAvailable => _isInitialized && _speech.isAvailable;
}
