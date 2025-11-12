import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SmartSalesApp());
}

class SmartSalesApp extends StatelessWidget {
  const SmartSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Paleta: azul mate (solo azul y blanco)
  const Color matteBlue = Color(0xFF2F4F6F); // azul mate
    const Color whiteColor = Color(0xFFFFFFFF);

    return MaterialApp(
      title: 'SmartSales365',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: matteBlue,
          onPrimary: whiteColor,
          secondary: matteBlue,
          onSecondary: whiteColor,
          error: Colors.red,
          onError: whiteColor,
          background: whiteColor,
          onBackground: matteBlue,
          surface: whiteColor,
          onSurface: matteBlue,
        ),
        primaryColor: matteBlue,
        scaffoldBackgroundColor: whiteColor,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: matteBlue,
          foregroundColor: whiteColor,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: matteBlue,
          foregroundColor: whiteColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: matteBlue,
            foregroundColor: whiteColor,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Splash screen que verifica si hay sesión activa
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// Verificar autenticación y navegar
  Future<void> _checkAuth() async {
    // Esperar un momento para mostrar splash
    await Future.delayed(const Duration(seconds: 2));

    final isLoggedIn = await _authService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Intentar obtener el perfil del usuario
      try {
        final user = await _authService.getProfile();

        // Navegar al home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
        );
      } catch (e) {
        // Error al obtener perfil, ir a login
        await _authService.logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      // No hay sesión, ir a login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade800],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o icono
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Título
              const Text(
                'SmartSales365',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Sistema de Gestión Inteligente',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 48),

              // Indicador de carga
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
