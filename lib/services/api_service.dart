// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class ApiService {
  // ⚡ Para Android Emulator, 10.0.2.2 apunta a tu PC host
  static String baseUrl =
      'http://192.168.1.5:3000'; // Cambia esto por tu IP local o ngrok
  static String? token;

  // Encabezados para peticiones
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token?.isNotEmpty == true) 'Authorization': 'Bearer $token',
  };

  // Guardar token en memoria
  static void setToken(String? t) => token = t;

  // LOGIN
  static Future<Map<String, dynamic>> login(
    String cedula,
    String password,
  ) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');

    try {
      final resp = await http.post(
        uri,
        headers: headers, // usamos la propiedad headers
        body: jsonEncode({'cedula': cedula, 'password': password}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        // Guardar token en memoria y SharedPreferences
        setToken(data['token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);

        print('Login exitoso: ${data['empleado']['nombre']}'); // Consola
        await NotificationService.registrarToken(data['empleado']['id']);

        return data; // Devuelve todo el JSON
      } else {
        final data = jsonDecode(resp.body);
        throw Exception(data['error'] ?? 'Login fallido');
      }
    } catch (e) {
      print('Error login: $e');
      throw Exception('Error login: $e');
    }
  }

  // LOGOUT
  static Future<void> logout() async {
    setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    print('Usuario deslogueado');
  }

  static Future<List<Map<String, dynamic>>> getEventosEmpleado(
    int empleadoId,
  ) async {
    final uri = Uri.parse('$baseUrl/api/empleado-eventos/empleado/$empleadoId');

    try {
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al cargar eventos: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error getEventosEmpleado: $e');
      throw Exception('Error getEventosEmpleado: $e');
    }
  }

  static Future<Map<String, dynamic>?> getAsistenciaActiva() async {
    final uri = Uri.parse('$baseUrl/api/asistencias/activa');
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data; // puede ser null si no hay activa
    }
    return null;
  }
}
