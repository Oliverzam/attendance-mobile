# App Móvil de Asistencia — Flutter

![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase_FCM-15.0-FFCA28?logo=firebase&logoColor=black)
![Provider](https://img.shields.io/badge/Provider-6.1-0175C2?logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-API_21+-34A853?logo=android&logoColor=white)

Aplicación móvil para empleados que permite registrar asistencia con validación GPS, consultar historial y reportes mensuales, ver eventos del calendario y recibir notificaciones push en tiempo real. Desarrollada en Flutter con integración completa a Firebase Cloud Messaging.

---

## Funcionalidades principales

- **Registro de asistencia** con geolocalización: entrada, salida, inicio y regreso de almuerzo
- **Validación GPS** en tiempo real: el backend verifica que el empleado esté dentro del perímetro autorizado
- **Historial y reportes** del mes con KPIs: horas trabajadas, puntualidad y asistencia a eventos
- **Calendario de eventos** con vista mensual y detalle de cada jornada especial
- **Notificaciones push** en tiempo real vía Firebase Cloud Messaging (FCM)
- **Centro de notificaciones** con secciones leídas/no leídas y archivo por swipe
- **Tema claro/oscuro** con persistencia de preferencia del usuario
- **Autenticación JWT** con almacenamiento seguro en SharedPreferences

---

## Stack tecnológico

| Capa | Tecnología | Versión |
|------|-----------|---------|
| Framework | Flutter | SDK ≥3.10.7 |
| Lenguaje | Dart | ^3.10.7 |
| HTTP | http | 1.2.2 |
| Estado global | Provider | 6.1.2 |
| Notificaciones push | firebase_messaging | 15.0.0 |
| Firebase Core | firebase_core | 3.0.0 |
| Geolocalización | geolocator | 14.0.0 |
| Mapas | flutter_map | 6.1.0 |
| Calendario | table_calendar | 3.1.2 |
| Persistencia local | shared_preferences | 2.3.1 |
| SDK Android mínimo | — | API 21 (Android 5.0+) |

---

## Requisitos previos

- Flutter SDK 3.10.7 o superior (`flutter --version`)
- Android SDK con platform API 21 o superior
- Proyecto Firebase activo con la app Android registrada
- Backend API corriendo (ver `registro_asistencia/`)

---

## Instalación

```bash
# 1. Clonar el repositorio
git clone <url-del-repo>
cd hola

# 2. Instalar dependencias
flutter pub get

# 3. Verificar que el entorno esté listo
flutter doctor

# 4. Configurar la URL del backend
# Editar lib/services/api_service.dart y cambiar baseUrl:
# static String baseUrl = 'http://TU_IP_O_DOMINIO:3000';

# 5. Correr en desarrollo
flutter run
```

---

## Configuración de Firebase

El archivo `google-services.json` debe estar en `android/app/`. Si conectas tu propio proyecto Firebase:

1. Ir a la consola de Firebase → Configuración del proyecto → Agregar app Android
2. Registrar el package name (ver `android/app/build.gradle`)
3. Descargar `google-services.json` y colocarlo en `android/app/`
4. Ejecutar `flutterfire configure` para regenerar `lib/firebase_options.dart`

---

## Comandos

```bash
flutter run                         # Desarrollo con hot-reload
flutter run --release               # Modo producción en dispositivo físico
flutter build apk                   # APK universal para distribución
flutter build apk --split-per-abi   # APKs optimizados por arquitectura ARM/x86
flutter build appbundle             # Android App Bundle para Google Play Store
```

---

## Estructura del proyecto

```
lib/
├── main.dart                       # Punto de entrada, inicialización de Firebase
├── firebase_options.dart           # Configuración generada por FlutterFire CLI
├── screens/
│   ├── login_screen.dart           # Autenticación con cédula y contraseña
│   └── home_screen.dart            # Shell con BottomNavigationBar (5 tabs)
├── tabs/
│   ├── home_tab.dart               # Inicio: resumen del empleado y acciones rápidas
│   ├── asistencia_tab.dart         # Registro GPS: entrada, salida y almuerzo
│   ├── eventos_tab.dart            # Calendario mensual y lista de eventos
│   ├── reportes_tab.dart           # Reportes del mes con KPIs y progress bars
│   └── notificaciones_tab.dart     # Centro de notificaciones con swipe-to-archive
├── services/
│   ├── api_service.dart            # Cliente HTTP hacia el backend REST
│   └── notification_service.dart   # Registro FCM y consulta de notificaciones
├── models/
│   ├── empleado_model.dart         # Modelo de empleado
│   └── notificacion_model.dart     # Notificación con estado leído/no leído
├── providers/
│   └── theme_provider.dart         # Estado global del tema (claro/oscuro)
└── theme/
    └── app_theme.dart              # Paleta corporativa y definición de temas
```

---

## Paleta de colores corporativa

| Token | Valor | Uso |
|-------|-------|-----|
| `_kPrimary` | `#185FA5` | Acentos, botones, indicadores activos |
| `_kNavy` | `#0C1A3A` | Headers de pantalla y barra de navegación |
| Ícono adaptativo | `#0C0458` | Fondo del ícono en Android |

---

## Arquitectura de navegación

```
LoginScreen
    └── HomeScreen (BottomNavigationBar)
            ├── [0] HomeTab          → Resumen y accesos rápidos
            ├── [1] AsistenciaTab    → Registro GPS
            ├── [2] EventosTab       → Calendario
            ├── [3] ReportesTab      → Reportes mensuales
            └── [4] NotificacionesTab→ Centro de notificaciones (badge con contador)
```

El badge de notificaciones se actualiza automáticamente al recibir mensajes FCM en primer y segundo plano, y al restaurar la app desde background.
