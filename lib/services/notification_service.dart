import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/notificacion_model.dart';

class NotificationService {
  static const String baseUrl =
      'http://192.168.1.5:3000'; // Cambia esto por tu IP local o ngrok
  static String? authToken;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  // ─── TOKEN FCM ────────────────────────────────────────────────

  // Llama esto justo después del login exitoso
  static Future<void> registrarToken(int empleadoId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final response = await http.patch(
        Uri.parse(
          '$baseUrl/api/notificaciones/empleados/$empleadoId/device-token',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_token': token}),
      );

      if (response.statusCode == 200) {
        print('✅ Token registrado correctamente');
      } else {
        print('❌ Error al registrar token: ${response.body}');
      }
    } catch (e) {
      print('❌ Excepción: $e');
    }
  }

  // Llama esto al cerrar sesión
  static Future<void> borrarToken(int empleadoId) async {
    try {
      await http.delete(
        Uri.parse(
          '$baseUrl/api/notificaciones/empleados/$empleadoId/device-token',
        ),
        headers: _headers,
      );
      print('🗑️ Token eliminado');
    } catch (e) {
      print('❌ Error al borrar token: $e');
    }
  }

  // ─── NOTIFICACIONES ───────────────────────────────────────────

  // GET /api/notificaciones/empleados/:empleado_id
  static Future<List<NotificacionModel>> obtenerNotificaciones(
    int empleadoId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/notificaciones/empleados/$empleadoId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => NotificacionModel.fromMap(item)).toList();
    } else {
      throw Exception('Error al obtener notificaciones: ${response.body}');
    }
  }

  // PATCH /api/notificaciones/empleados/:empleado_id/notificaciones/:notificacion_id/recibida
  static Future<void> marcarComoRecibida(
    int empleadoId,
    int notificacionId,
  ) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/api/notificaciones/empleados/$empleadoId/notificaciones/$notificacionId/recibida',
      ),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Error al marcar notificación: ${response.body}');
    }
  }

  static Future<void> archivarNotificacion(
    int empleadoId,
    int notificacionId,
  ) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/api/notificaciones/empleados/$empleadoId/notificaciones/$notificacionId/archivar',
      ),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Error al archivar: ${response.body}');
    }
  }
}
