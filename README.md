# 🏪 SmartSales365 - Sistema de Gestión Inteligente

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.9.2-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-Private-red.svg)](LICENSE)

Sistema de Gestión Inteligente con IA y Reconocimiento de Voz para administración de ventas, clientes, productos e inventario.

## ✨ Características

### 🎤 Consulta IA con Voz
- Reconocimiento de voz en español
- Generación automática de reportes mediante comandos de voz
- Interpretación inteligente de lenguaje natural

### 📊 Generación de Reportes
- **Ventas**: Reportes completos con agrupaciones por producto, cliente, categoría o fecha
- **Clientes**: Análisis de clientes activos y comportamiento de compra
- **Productos**: Catálogos con ventas totales y estadísticas
- **Inventario**: Control de stock y valor monetario

### 📄 Múltiples Formatos de Exportación
- PDF con diseño profesional
- Excel con formato y filtros
- CSV para análisis de datos
- Visualización en pantalla (JSON)

### 🎨 Diseño Moderno
- Interfaz moderna con Material Design 3
- Animaciones fluidas y transiciones
- Experiencia de usuario optimizada
- Diseño responsive

## 🚀 Requisitos Previos

- Flutter SDK 3.9.2 o superior
- Dart SDK 3.9.2 o superior
- Android Studio / Xcode (para desarrollo móvil)
- Acceso al servidor backend en `https://smartsales365.duckdns.org`

## 📦 Instalación

### 1. Clonar el repositorio

```bash
git clone <repository-url>
cd smartsales
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar permisos

#### Android
Los permisos ya están configurados en `android/app/src/main/AndroidManifest.xml`:
- INTERNET
- RECORD_AUDIO
- WRITE_EXTERNAL_STORAGE
- READ_EXTERNAL_STORAGE

#### iOS
Los permisos ya están configurados en `ios/Runner/Info.plist`:
- NSMicrophoneUsageDescription
- NSSpeechRecognitionUsageDescription

### 4. Ejecutar la aplicación

```bash
# Modo debug
flutter run

# Modo release
flutter run --release
```

## 🏗️ Arquitectura del Proyecto

```
lib/
├── main.dart                      # Punto de entrada de la aplicación
├── models/                        # Modelos de datos
│   ├── user_model.dart
│   └── login_response.dart
├── screens/                       # Pantallas de la aplicación
│   ├── login_screen.dart         # Pantalla de login con animaciones
│   ├── home_screen.dart          # Dashboard principal
│   └── ia_voice_screen.dart      # Pantalla de consulta IA con voz
└── services/                      # Servicios de negocio
    ├── auth_service.dart         # Autenticación y gestión de sesión
    ├── ia_api_service.dart       # Integración con API de IA
    └── voice_service.dart        # Reconocimiento de voz
```

## 🔐 Autenticación

La aplicación utiliza autenticación basada en tokens:

1. Login con credenciales de administrador
2. Recepción de token JWT
3. Almacenamiento seguro con SharedPreferences
4. Inclusión del token en todas las peticiones API

### Endpoint de Login

```
POST https://smartsales365.duckdns.org/api/usuarios/token/
Content-Type: application/json

{
  "username": "admin",
  "password": "your_password"
}
```

## 🎤 Uso del Sistema de IA

### Ejemplos de Comandos de Voz

**Ventas:**
- "Quiero un reporte de ventas del mes de octubre en PDF"
- "Ventas del último mes agrupadas por producto en Excel"
- "Top 10 productos más vendidos"

**Clientes:**
- "Clientes activos del último mes"
- "Top 5 clientes con más compras"

**Productos:**
- "Productos más vendidos en CSV"
- "Inventario actual en Excel"

**Inventario:**
- "Muéstrame el inventario actual con stock y valor"
- "Productos con bajo stock"

### Características del Procesamiento de IA

- **Detección automática de fechas**: Entiende meses en español, rangos relativos y fechas específicas
- **Agrupaciones inteligentes**: Por producto, cliente, categoría o fecha
- **Filtros automáticos**: Estado de pago, categorías específicas
- **Límites y ordenamiento**: Top N, ordenamiento ascendente/descendente

## 📱 Características de la Interfaz

### Splash Screen
- Carga automática de sesión guardada
- Animación de bienvenida
- Navegación inteligente

### Login Screen
- Diseño moderno con gradientes
- Animaciones de entrada
- Validación en tiempo real
- Manejo de errores amigable

### Dashboard (Home)
- Tarjeta de bienvenida personalizada
- Acceso rápido a funcionalidades
- Diseño con animaciones fluidas
- SliverAppBar con gradiente

### IA Voice Screen
- Botón de micrófono animado con efecto glow
- Indicador de estado en tiempo real
- Ejemplos de consultas interactivos
- Visualización de resultados en tablas
- Descarga y apertura automática de archivos

## 🛠️ Dependencias Principales

```yaml
dependencies:
  # UI
  cupertino_icons: ^1.0.8
  
  # Networking & API
  http: ^1.2.0
  
  # Storage
  shared_preferences: ^2.2.3
  path_provider: ^2.1.2
  
  # Voice Recognition (IA)
  speech_to_text: ^7.0.0
  
  # Permissions
  permission_handler: ^11.3.0
  
  # File Handling
  open_file: ^3.3.2
```

## 🔧 Configuración del Backend

El backend debe estar disponible en:
```
https://smartsales365.duckdns.org
```

### Endpoints Principales

- **Login**: `POST /api/usuarios/token/`
- **Perfil**: `GET /api/usuarios/me/`
- **Consulta IA**: `POST /api/ia/consulta/`
- **Health Check**: `GET /api/ia/health/`

## 🐛 Solución de Problemas

### ⚠️ Error CORS en Flutter Web

Si ves `ClientException: Failed to fetch` en Flutter Web:

**Este es un problema de CORS que SOLO afecta a Flutter Web.**

**Solución Rápida:**
```bash
# Ejecuta en Android o iOS (no tienen CORS)
flutter run -d android
# o
flutter run -d ios
```

**📖 Lee la guía completa:** [SOLUCION_CORS_WEB.md](SOLUCION_CORS_WEB.md)

**Resumen:**
- ✅ **Android/iOS**: Funcionan perfectamente (sin CORS)
- ⚠️ **Web**: Requiere configuración CORS en el backend
- 🔧 **Backend**: Necesita `django-cors-headers` configurado

---

### Error de Conexión

Si aparece error de conexión al servidor:
1. Verifica que el backend esté corriendo en `https://smartsales365.duckdns.org`
2. Verifica tu conexión a internet
3. Revisa los logs en la consola
4. **Para Web**: Lee [SOLUCION_CORS_WEB.md](SOLUCION_CORS_WEB.md)

### Error de Micrófono

Si el micrófono no funciona:
1. Verifica que los permisos estén concedidos
2. Reinicia la aplicación
3. Verifica que el dispositivo tenga micrófono funcional

### Error en Generación de Reportes

Si falla la generación de reportes:
1. Verifica que el prompt tenga al menos 10 caracteres
2. Usa palabras clave claras (ventas, clientes, productos, inventario)
3. Especifica el formato deseado (PDF, Excel, CSV)

## 📚 Documentación Adicional

- [FLUTTER_IA_VOZ.md](FLUTTER_IA_VOZ.md) - Documentación completa de la integración con IA
- [FLUTTER_ADMIN_DASHBOARD.md](FLUTTER_ADMIN_DASHBOARD.md) - Guía del dashboard de administrador
- [FLUTTER_REPORTES_VOZ.md](FLUTTER_REPORTES_VOZ.md) - Sistema de reportes por voz

## 🎯 Roadmap

- [ ] Modo offline con caché
- [ ] Notificaciones push
- [ ] Gráficas y visualizaciones avanzadas
- [ ] Exportación a más formatos
- [ ] Soporte multiidioma
- [ ] Modo oscuro

## 👥 Equipo de Desarrollo

Desarrollado por el equipo de SmartSales365

## 📄 Licencia

Este proyecto es privado y confidencial.

---

**SmartSales365** - Sistema de Gestión Inteligente con IA 🚀
