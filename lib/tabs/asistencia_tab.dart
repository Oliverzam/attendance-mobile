import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';

const _kPrimary = Color(0xFF4361EE);
const _kEntrada = Color(0xFF10B981);
const _kSalida = Color(0xFFEF4444);
const _kAmbar = Color(0xFFF59E0B);
const _kAlmuerzo = Color(0xFFF97316);

class AsistenciaTab extends StatefulWidget {
  final int empleadoId;
  const AsistenciaTab({super.key, required this.empleadoId});

  @override
  State<AsistenciaTab> createState() => _AsistenciaTabState();
}

class _AsistenciaTabState extends State<AsistenciaTab> {
  bool isLoading = true;
  Map<String, dynamic>? asistenciaActiva;
  Map<String, dynamic>? horario;
  Timer? _timer;
  Duration _tiempoTranscurrido = Duration.zero;
  String? _estadoFlujo;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ================= CARGA INICIAL =================
  Future<void> _cargarDatos() async {
    setState(() => isLoading = true);
    await Future.wait([_cargarAsistenciaActiva(), _cargarHorario()]);
    setState(() => isLoading = false);
  }

  Future<void> _cargarAsistenciaActiva() async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/activa'),
        headers: ApiService.headers,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        // ✅ CAMBIO 1: Se eliminó el filtro por tipo 'diaria' para permitir
        // múltiples asistencias en el mismo día. Acepta cualquier asistencia activa.
        asistenciaActiva = (data != null) ? data : null;
        _actualizarEstadoFlujo();
        if (asistenciaActiva != null && !_esIncompleta) _iniciarCronometro();
      }
    } catch (e) {
      print('Error al cargar asistencia activa: $e');
    }
  }

  Future<void> _cargarHorario() async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/horarios/mi-horario'),
        headers: ApiService.headers,
      );
      if (resp.statusCode == 200) {
        horario = jsonDecode(resp.body);
      }
    } catch (e) {
      print('Error al cargar horario: $e');
    }
  }

  // ================= ESTADO DEL FLUJO =================
  void _actualizarEstadoFlujo() {
    if (asistenciaActiva == null) {
      _estadoFlujo = null;
      return;
    }
    final a = asistenciaActiva!;
    if (a['hora_salida'] != null) {
      _estadoFlujo = 'completado';
    } else if (a['salida_almuerzo'] != null && a['regreso_almuerzo'] == null) {
      _estadoFlujo = 'regreso_almuerzo';
    } else if (a['salida_almuerzo'] == null && a['hora_entrada'] != null) {
      _estadoFlujo = 'entrada';
    } else if (a['regreso_almuerzo'] != null) {
      _estadoFlujo = 'regreso_almuerzo_hecho';
    }
  }

  bool get _tieneAlmuerzo =>
      horario != null &&
      horario!['tiene_almuerzo'] == true &&
      asistenciaActiva != null &&
      asistenciaActiva!['horario_id'] != null;

  bool get _esIncompleta => asistenciaActiva?['incompleta'] == true;

  // ================= CRONÓMETRO =================
  void _iniciarCronometro() {
    _timer?.cancel();
    if (asistenciaActiva == null || _esIncompleta) return;
    final horaEntrada = DateTime.parse(
      asistenciaActiva!['hora_entrada'],
    ).toLocal();
    _tiempoTranscurrido = DateTime.now().difference(horaEntrada);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted)
        setState(() => _tiempoTranscurrido += const Duration(seconds: 1));
    });
  }

  String get _cronometroStr {
    final h = _tiempoTranscurrido.inHours.toString().padLeft(2, '0');
    final m = (_tiempoTranscurrido.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_tiempoTranscurrido.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ================= PERMISOS Y POSICIÓN =================
  Future<bool> _asegurarPermisosUbicacion() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Activa el GPS', _kSalida);
      return false;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showSnack('Permiso de ubicación denegado', _kSalida);
      return false;
    }
    return true;
  }

  Future<Position?> _obtenerPosicion() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      _showSnack('Error al obtener ubicación: $e', _kSalida);
      return null;
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ================= ACCIONES =================
  Future<void> _registrarEntrada() async {
    if (!await _asegurarPermisosUbicacion()) return;
    final posicion = await _obtenerPosicion();
    if (posicion == null) return;

    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/entrada'),
        headers: ApiService.headers,
        body: jsonEncode({
          "tipo": "diaria",
          "latitud_registro": posicion.latitude.toString(),
          "longitud_registro": posicion.longitude.toString(),
        }),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        if (data['horario'] != null) horario = data['horario'];
        setState(() {
          asistenciaActiva = data;
          _actualizarEstadoFlujo();
        });
        _iniciarCronometro();
        if (data['tardanza'] == true) {
          _showSnack('⚠️ Entrada registrada con tardanza', _kAmbar);
        } else {
          _showSnack('✅ Entrada registrada correctamente', _kEntrada);
        }
      } else {
        final error = jsonDecode(resp.body);
        _showSnack(error['error'] ?? 'Error desconocido', _kSalida);
      }
    } catch (e, stackTrace) {
      print('Error detallado: $e');
      print('StackTrace: $stackTrace');
      _showSnack('Error de conexión: $e', _kSalida);
    }
  }

  Future<void> _registrarSalidaAlmuerzo() async {
    if (!await _asegurarPermisosUbicacion()) return;
    final posicion = await _obtenerPosicion();
    if (posicion == null) return;

    try {
      final resp = await http.put(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/almuerzo-salida'),
        headers: ApiService.headers,
        body: jsonEncode({
          "latitud_registro": posicion.latitude.toString(),
          "longitud_registro": posicion.longitude.toString(),
        }),
      );

      if (resp.statusCode == 200) {
        setState(() {
          asistenciaActiva!['salida_almuerzo'] = DateTime.now()
              .toIso8601String();
          _actualizarEstadoFlujo();
        });
        _showSnack('🍽️ Salida de almuerzo registrada', _kAmbar);
      } else {
        final error = jsonDecode(resp.body);
        _showSnack(error['error'] ?? 'Error desconocido', _kSalida);
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', _kSalida);
    }
  }

  Future<void> _registrarRegresoAlmuerzo() async {
    if (!await _asegurarPermisosUbicacion()) return;
    final posicion = await _obtenerPosicion();
    if (posicion == null) return;

    try {
      final resp = await http.put(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/almuerzo-regreso'),
        headers: ApiService.headers,
        body: jsonEncode({
          "latitud_registro": posicion.latitude.toString(),
          "longitud_registro": posicion.longitude.toString(),
        }),
      );

      if (resp.statusCode == 200) {
        setState(() {
          asistenciaActiva!['regreso_almuerzo'] = DateTime.now()
              .toIso8601String();
          _actualizarEstadoFlujo();
        });
        _showSnack('🔙 Regreso de almuerzo registrado', _kEntrada);
      } else {
        final error = jsonDecode(resp.body);
        _showSnack(error['error'] ?? 'Error desconocido', _kSalida);
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', _kSalida);
    }
  }

  Future<void> _registrarSalida({String? motivo}) async {
    if (!await _asegurarPermisosUbicacion()) return;
    final posicion = await _obtenerPosicion();
    if (posicion == null) return;

    try {
      final resp = await http.put(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/salida'),
        headers: ApiService.headers,
        body: jsonEncode({
          "latitud_registro": posicion.latitude.toString(),
          "longitud_registro": posicion.longitude.toString(),
          if (motivo != null) "motivo_salida_anticipada": motivo,
        }),
      );

      if (resp.statusCode == 200) {
        _timer?.cancel();
        // ✅ CAMBIO 1: Al limpiar asistenciaActiva después de la salida,
        // el botón de Entrada vuelve a habilitarse para registrar una nueva
        // jornada el mismo día sin restricción.
        setState(() {
          asistenciaActiva = null;
          _estadoFlujo = null;
          _tiempoTranscurrido = Duration.zero;
        });
        _showSnack('✅ Salida registrada correctamente', _kEntrada);
      } else {
        final error = jsonDecode(resp.body);
        if (error['salida_anticipada'] == true) {
          _mostrarDialogoSalidaAnticipada();
          return;
        }
        _showSnack(error['error'] ?? 'Error desconocido', _kSalida);
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', _kSalida);
    }
  }

  void _mostrarDialogoSalidaAnticipada() {
    final TextEditingController motivoController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kAmbar),
            SizedBox(width: 8),
            Text('Salida anticipada', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estás saliendo antes de tu hora. Por favor indica el motivo:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Cita médica, emergencia familiar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kPrimary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final motivo = motivoController.text.trim();
              if (motivo.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('El motivo no puede estar vacío'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              _registrarSalida(motivo: motivo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kSalida,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Confirmar salida',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ================= HELPERS =================
  String _formatHora(String? fecha) {
    if (fecha == null) return '--:--';
    final d = DateTime.parse(fecha).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _horasEstimadas() {
    final h = _tiempoTranscurrido.inHours;
    final m = _tiempoTranscurrido.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final bool tieneEntrada = asistenciaActiva != null;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double? lat = tieneEntrada
        ? double.tryParse(
            asistenciaActiva!['latitud_registro']?.toString() ?? '',
          )
        : null;
    final double? lng = tieneEntrada
        ? double.tryParse(
            asistenciaActiva!['longitud_registro']?.toString() ?? '',
          )
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: _kPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEstadoCard(
                context,
                tieneEntrada,
                cardColor,
                colorScheme,
                isDark,
              ),
              const SizedBox(height: 16),

              if (tieneEntrada) ...[
                _buildBadges(context),
                const SizedBox(height: 16),
              ],

              if (horario != null) ...[
                _buildHorarioCard(context, cardColor, colorScheme),
                const SizedBox(height: 16),
              ],

              if (tieneEntrada && !_esIncompleta) ...[
                _buildCronometro(context, cardColor, colorScheme),
                const SizedBox(height: 16),
              ],

              if (tieneEntrada) ...[
                _buildFlujoMarcaciones(context, cardColor, colorScheme),
                const SizedBox(height: 16),
              ],

              _buildResumenDia(context, tieneEntrada, cardColor, colorScheme),
              const SizedBox(height: 16),

              if (tieneEntrada && lat != null && lng != null) ...[
                _buildMapa(context, lat, lng, cardColor, colorScheme),
                const SizedBox(height: 16),
              ],

              _buildBotones(tieneEntrada),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= WIDGETS =================

  Widget _buildBadges(BuildContext context) {
    final a = asistenciaActiva!;
    final badges = <Widget>[];

    if (a['incompleta'] == true) {
      badges.add(
        _Badge(
          icono: Icons.warning_rounded,
          label: 'Jornada incompleta',
          color: _kSalida,
        ),
      );
    }
    if (a['tardanza'] == true) {
      badges.add(
        _Badge(
          icono: Icons.access_time_filled_rounded,
          label: 'Tardanza',
          color: _kAmbar,
        ),
      );
    }
    if (a['salida_anticipada'] == true) {
      badges.add(
        _Badge(
          icono: Icons.exit_to_app_rounded,
          label: 'Salida anticipada',
          color: _kSalida,
        ),
      );
    }
    if (a['salida_tardia'] == true) {
      badges.add(
        _Badge(
          icono: Icons.more_time_rounded,
          label: 'Salida tardía',
          color: _kPrimary,
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: badges);
  }

  Widget _buildHorarioCard(
    BuildContext context,
    Color cardColor,
    ColorScheme colorScheme,
  ) {
    final tieneAlmuerzo = horario!['tiene_almuerzo'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: _kPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  horario!['nombre'] ?? 'Mi Horario',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(horario!['hora_inicio'] as String?)?.substring(0, 5) ?? '--'} → ${(horario!['hora_fin'] as String?)?.substring(0, 5) ?? '--'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (tieneAlmuerzo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kAlmuerzo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kAlmuerzo.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_rounded, color: _kAlmuerzo, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Con almuerzo',
                    style: TextStyle(
                      fontSize: 11,
                      color: _kAlmuerzo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlujoMarcaciones(
    BuildContext context,
    Color cardColor,
    ColorScheme colorScheme,
  ) {
    final a = asistenciaActiva!;
    final tieneAlmuerzo = _tieneAlmuerzo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flujo del día',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _FlowStep(
                icono: Icons.login_rounded,
                label: 'Entrada',
                hora: _formatHora(a['hora_entrada']),
                color: _kEntrada,
                done: true,
              ),
              if (tieneAlmuerzo) ...[
                _FlowArrow(done: a['salida_almuerzo'] != null),
                _FlowStep(
                  icono: Icons.restaurant_rounded,
                  label: 'Almuerzo',
                  hora: _formatHora(a['salida_almuerzo']),
                  color: _kAlmuerzo,
                  done: a['salida_almuerzo'] != null,
                ),
                _FlowArrow(done: a['regreso_almuerzo'] != null),
                _FlowStep(
                  icono: Icons.keyboard_return_rounded,
                  label: 'Regreso',
                  hora: _formatHora(a['regreso_almuerzo']),
                  color: _kPrimary,
                  done: a['regreso_almuerzo'] != null,
                ),
              ],
              _FlowArrow(done: a['hora_salida'] != null),
              _FlowStep(
                icono: Icons.logout_rounded,
                label: 'Salida',
                hora: _formatHora(a['hora_salida']),
                color: _kSalida,
                done: a['hora_salida'] != null,
              ),
            ],
          ),
          if (a['salida_anticipada'] == true &&
              a['motivo_salida_anticipada'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kSalida.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kSalida.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: _kSalida, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Motivo salida anticipada: ${a['motivo_salida_anticipada']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kSalida,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (a['incompleta'] == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kSalida.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kSalida.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: _kSalida, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Esta jornada fue cerrada automáticamente por no registrar salida.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kSalida,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadoCard(
    BuildContext context,
    bool tieneEntrada,
    Color cardColor,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    String titulo = 'Sin asistencia activa';
    String subtitulo = 'Registra tu entrada para comenzar';
    List<Color> gradientColors = [const Color(0xFF1A237E), _kPrimary];

    if (tieneEntrada) {
      final a = asistenciaActiva!;
      if (a['incompleta'] == true) {
        titulo = 'Jornada incompleta';
        subtitulo = 'No registraste tu salida';
        gradientColors = [const Color(0xFF7F1D1D), _kSalida];
      } else if (a['salida_almuerzo'] != null &&
          a['regreso_almuerzo'] == null) {
        titulo = 'En almuerzo';
        subtitulo = 'Salida: ${_formatHora(a['salida_almuerzo'])}';
        gradientColors = [const Color(0xFFB45309), _kAmbar];
      } else if (a['regreso_almuerzo'] != null && a['hora_salida'] == null) {
        titulo = 'Jornada en curso';
        subtitulo = 'Regresó: ${_formatHora(a['regreso_almuerzo'])}';
        gradientColors = [const Color(0xFF059669), _kEntrada];
      } else {
        titulo = 'Jornada en curso';
        subtitulo = 'Entrada: ${_formatHora(a['hora_entrada'])}';
        gradientColors = [const Color(0xFF059669), _kEntrada];
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              tieneEntrada
                  ? (_esIncompleta ? Icons.warning_rounded : Icons.lock_clock)
                  : Icons.fingerprint,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (tieneEntrada && asistenciaActiva!['tardanza'] == true)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCronometro(
    BuildContext context,
    Color cardColor,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(
            'Tiempo transcurrido',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _cronometroStr,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'hh : mm : ss',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenDia(
    BuildContext context,
    bool tieneEntrada,
    Color cardColor,
    ColorScheme colorScheme,
  ) {
    final a = asistenciaActiva;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen del día',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResumenItem(
                  icono: Icons.login_rounded,
                  label: 'Entrada',
                  valor: tieneEntrada
                      ? _formatHora(a!['hora_entrada'])
                      : '--:--',
                  color: _kEntrada,
                ),
              ),
              if (_tieneAlmuerzo) ...[
                Expanded(
                  child: _ResumenItem(
                    icono: Icons.restaurant_rounded,
                    label: 'Almuerzo',
                    valor: a?['salida_almuerzo'] != null
                        ? _formatHora(a!['salida_almuerzo'])
                        : '--:--',
                    color: _kAlmuerzo,
                  ),
                ),
              ],
              Expanded(
                child: _ResumenItem(
                  icono: Icons.logout_rounded,
                  label: 'Salida',
                  valor: a?['hora_salida'] != null
                      ? _formatHora(a!['hora_salida'])
                      : '--:--',
                  color: _kSalida,
                ),
              ),
              Expanded(
                child: _ResumenItem(
                  icono: Icons.timer_rounded,
                  label: 'Tiempo',
                  valor: tieneEntrada && !_esIncompleta
                      ? _horasEstimadas()
                      : '0h 00m',
                  color: _kAmbar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapa(
    BuildContext context,
    double lat,
    double lng,
    Color cardColor,
    ColorScheme colorScheme,
  ) {
    final punto = LatLng(lat, lng);
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: _kPrimary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ubicación de entrada',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: punto,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.hola',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: punto,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_pin,
                          color: _kSalida,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotones(bool tieneEntrada) {
    final a = asistenciaActiva;
    final bool enAlmuerzo =
        a != null &&
        a['salida_almuerzo'] != null &&
        a['regreso_almuerzo'] == null;

    final bool puedeRegistrarSalidaAlmuerzo =
        tieneEntrada &&
        !_esIncompleta &&
        _tieneAlmuerzo &&
        // ✅ CAMBIO 2: Se eliminó cualquier validación de hora para almuerzo.
        // El botón está disponible en cualquier momento mientras no se haya
        // registrado ya la salida de almuerzo.
        a!['salida_almuerzo'] == null;

    final bool puedeRegistrarRegresoAlmuerzo =
        tieneEntrada && !_esIncompleta && enAlmuerzo;

    // ✅ CAMBIO: Se eliminó la obligación de completar el flujo de almuerzo.
    // El empleado puede registrar salida en cualquier momento sin importar
    // si salió o regresó del almuerzo.
    final bool puedeSalir = tieneEntrada && !_esIncompleta;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: tieneEntrada ? null : _registrarEntrada,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Registrar Entrada'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kEntrada,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kEntrada.withOpacity(0.3),
              disabledForegroundColor: Colors.white54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (_tieneAlmuerzo || enAlmuerzo) ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: puedeRegistrarSalidaAlmuerzo
                        ? _registrarSalidaAlmuerzo
                        : null,
                    icon: const Icon(Icons.restaurant_rounded, size: 18),
                    label: const Text('Sale almuerzo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAlmuerzo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kAlmuerzo.withOpacity(0.3),
                      disabledForegroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: puedeRegistrarRegresoAlmuerzo
                        ? _registrarRegresoAlmuerzo
                        : null,
                    icon: const Icon(Icons.keyboard_return_rounded, size: 18),
                    label: const Text('Regresa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kPrimary.withOpacity(0.3),
                      disabledForegroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: puedeSalir ? () => _registrarSalida() : null,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Registrar Salida'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kSalida,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kSalida.withOpacity(0.3),
              disabledForegroundColor: Colors.white54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================= WIDGETS AUXILIARES =================

class _Badge extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  const _Badge({required this.icono, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final IconData icono;
  final String label;
  final String hora;
  final Color color;
  final bool done;
  const _FlowStep({
    required this.icono,
    required this.label,
    required this.hora,
    required this.color,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: done ? color : color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icono,
            color: done ? Colors.white : color.withOpacity(0.5),
            size: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: done
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
        Text(
          hora,
          style: TextStyle(
            fontSize: 10,
            color: done
                ? color
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  final bool done;
  const _FlowArrow({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 28),
        decoration: BoxDecoration(
          color: done
              ? _kEntrada.withOpacity(0.5)
              : Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ResumenItem extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final Color color;
  const _ResumenItem({
    required this.icono,
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}
