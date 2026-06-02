import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// Colores institucionales coherentes con el resto de la app
const _kPrimary = Color(0xFF4361EE);
const _kEntrada = Color(0xFF10B981);
const _kSalida = Color(0xFFEF4444);

class Evento {
  final int empleadoEventoId;
  final int empleadoId;
  final int eventoId;
  final String titulo;
  final String fecha;
  final String hora;
  final String lugar;
  final String latitud;
  final String longitud;
  bool asistenciaRegistrada;
  bool salidaRegistrada;

  Evento({
    required this.empleadoEventoId,
    required this.empleadoId,
    required this.eventoId,
    required this.titulo,
    required this.fecha,
    required this.hora,
    required this.lugar,
    required this.latitud,
    required this.longitud,
    bool? asistenciaRegistrada,
    bool? salidaRegistrada,
  }) : asistenciaRegistrada = asistenciaRegistrada ?? false,
       salidaRegistrada = salidaRegistrada ?? false;

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      empleadoEventoId:
          json['empleado_evento_id'] ?? json['emplado_evento_id'] ?? 0,
      empleadoId: json['empleado_id'] ?? 0,
      eventoId: json['evento_id'] ?? 0,
      titulo: json['titulo'] ?? '',
      fecha: json['fecha'] ?? '',
      hora: json['hora'] ?? '',
      lugar: json['lugar'] ?? '',
      latitud: json['latitud']?.toString() ?? '0',
      longitud: json['longitud']?.toString() ?? '0',
    );
  }

  DateTime get fechaDateTime => DateTime.parse(fecha);
}

class EventosTab extends StatefulWidget {
  final int empleadoId;
  const EventosTab({super.key, required this.empleadoId});

  @override
  State<EventosTab> createState() => _EventosTabState();
}

class _EventosTabState extends State<EventosTab> {
  List<Evento> todosLosEventos = [];
  List<Evento> eventosDiaSeleccionado = [];
  bool isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<int, int> eventoAsistenciaId = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    fetchEventos();
  }

  List<Evento> _getEventosPorDia(DateTime dia) {
    return todosLosEventos.where((e) {
      final fecha = e.fechaDateTime;
      return fecha.year == dia.year &&
          fecha.month == dia.month &&
          fecha.day == dia.day;
    }).toList();
  }

  Future<bool> _asegurarPermisosUbicacion() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Activa el GPS')));
      return false;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de ubicación denegado')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
      return null;
    }
  }

  void _abrirMapa(Evento evento) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapaModal(
        latitud: double.parse(evento.latitud),
        longitud: double.parse(evento.longitud),
        nombreLugar: evento.lugar,
      ),
    );
  }

  Future<void> registrarEntradaEvento(Evento evento) async {
    final tienePermiso = await _asegurarPermisosUbicacion();
    if (!tienePermiso) return;
    final posicion = await _obtenerPosicion();
    if (posicion == null) return;

    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/entrada'),
        headers: ApiService.headers,
        body: jsonEncode({
          "eventos_id": evento.eventoId,
          "empleado_evento_id": evento.empleadoEventoId,
          "tipo": "evento",
          "latitud_registro": posicion.latitude.toString(),
          "longitud_registro": posicion.longitude.toString(),
        }),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        setState(() {
          evento.asistenciaRegistrada = true;
          eventoAsistenciaId[evento.empleadoEventoId] = data['id'] ?? 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Entrada registrada correctamente'),
            backgroundColor: _kEntrada,
          ),
        );
      } else {
        final errorData = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Error desconocido'),
            backgroundColor: _kSalida,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  Future<void> registrarSalidaEvento(Evento evento) async {
    final tienePermiso = await _asegurarPermisosUbicacion();
    if (!tienePermiso) return;
    final posicion = await _obtenerPosicion();
    if (posicion == null) return;

    try {
      final resp = await http.put(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/salida'),
        headers: ApiService.headers,
        body: jsonEncode({
          "latitud_registro": posicion.latitude.toString(),
          "longitud_registro": posicion.longitude.toString(),
        }),
      );

      if (resp.statusCode == 200) {
        setState(() => evento.salidaRegistrada = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Salida registrada correctamente'),
            backgroundColor: _kEntrada,
          ),
        );
      } else {
        final errorData = jsonDecode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['error'] ?? 'Error desconocido'),
            backgroundColor: _kSalida,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  void fetchEventos() async {
    try {
      final results = await Future.wait([
        ApiService.getEventosEmpleado(widget.empleadoId),
        ApiService.getAsistenciaActiva(),
      ]);

      final data = results[0] as List;
      final activa = results[1] as Map<String, dynamic>?;

      setState(() {
        todosLosEventos = data.map((e) => Evento.fromJson(e)).toList();
        if (activa != null && activa['tipo'] == 'evento') {
          for (var evento in todosLosEventos) {
            if (evento.eventoId == activa['eventos_id']) {
              evento.asistenciaRegistrada = true;
              eventoAsistenciaId[evento.empleadoEventoId] = activa['id'];
            }
          }
        }
        eventosDiaSeleccionado = _getEventosPorDia(_selectedDay!);
        isLoading = false;
      });
    } catch (e) {
      print('Error al cargar eventos: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading)
      return const Center(child: CircularProgressIndicator(color: _kPrimary));

    return Column(
      children: [
        // ======== Calendario ========
        TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2027, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventosPorDia,
          calendarStyle: CalendarStyle(
            // ✅ marcador de eventos
            markerDecoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
            // ✅ día seleccionado
            selectedDecoration: const BoxDecoration(
              color: _kPrimary,
              shape: BoxShape.circle,
            ),
            // ✅ hoy
            todayDecoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            // ✅ textos coherentes con el tema
            defaultTextStyle: TextStyle(color: colorScheme.onSurface),
            weekendTextStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            outsideTextStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: colorScheme.onSurface,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
              eventosDiaSeleccionado = _getEventosPorDia(selectedDay);
            });
          },
        ),

        Divider(color: Theme.of(context).dividerColor),

        // ======== Lista eventos ========
        Expanded(
          child: eventosDiaSeleccionado.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 64,
                        color: colorScheme.onSurface.withOpacity(0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay eventos este día',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: eventosDiaSeleccionado.length,
                  itemBuilder: (context, index) {
                    final evento = eventosDiaSeleccionado[index];
                    return _buildEventoCard(
                      context,
                      evento,
                      isDark,
                      colorScheme,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventoCard(
    BuildContext context,
    Evento evento,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor), // ✅
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título + badge hora
            Row(
              children: [
                Expanded(
                  child: Text(
                    evento.titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface, // ✅
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    evento.hora,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lugar + ver mapa
            Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 15,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    evento.lugar,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ), // ✅
                  ),
                ),
                GestureDetector(
                  onTap: () => _abrirMapa(evento),
                  child: const Row(
                    children: [
                      Icon(Icons.map_rounded, size: 15, color: _kPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Ver mapa',
                        style: TextStyle(
                          color: _kPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Botones entrada / salida
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: evento.asistenciaRegistrada
                        ? null
                        : () => registrarEntradaEvento(evento),
                    icon: Icon(
                      evento.asistenciaRegistrada
                          ? Icons.check_circle_rounded
                          : Icons.login_rounded,
                      size: 16,
                    ),
                    label: Text(
                      evento.asistenciaRegistrada
                          ? 'Entrada registrada'
                          : 'Registrar entrada',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kEntrada, // ✅ verde
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kEntrada.withOpacity(0.3),
                      disabledForegroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        evento.salidaRegistrada || !evento.asistenciaRegistrada
                        ? null
                        : () => registrarSalidaEvento(evento),
                    icon: Icon(
                      evento.salidaRegistrada
                          ? Icons.check_circle_rounded
                          : Icons.logout_rounded,
                      size: 16,
                    ),
                    label: Text(
                      evento.salidaRegistrada
                          ? 'Salida registrada'
                          : 'Registrar salida',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kSalida, // ✅ rojo
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kSalida.withOpacity(0.3),
                      disabledForegroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapaModal extends StatelessWidget {
  final double latitud;
  final double longitud;
  final String nombreLugar;

  const _MapaModal({
    required this.latitud,
    required this.longitud,
    required this.nombreLugar,
  });

  @override
  Widget build(BuildContext context) {
    final punto = LatLng(latitud, longitud);
    final cardColor = Theme.of(context).cardColor; // ✅

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: cardColor, // ✅
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: _kPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nombreLugar,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface, // ✅
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: FlutterMap(
                options: MapOptions(initialCenter: punto, initialZoom: 16),
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
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.location_pin,
                          color: _kSalida,
                          size: 48,
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
}
