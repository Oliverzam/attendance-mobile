import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

const _kPrimary = Color(0xFF185FA5);
const _kEntrada = Color(0xFF10B981);
const _kSalida  = Color(0xFFEF4444);
const _kNavy    = Color(0xFF0C1A3A);

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
      eventoId:   json['evento_id']   ?? 0,
      titulo:     json['titulo']      ?? '',
      fecha:      json['fecha']       ?? '',
      hora:       json['hora']        ?? '',
      lugar:      json['lugar']       ?? '',
      latitud:    json['latitud']?.toString()  ?? '0',
      longitud:   json['longitud']?.toString() ?? '0',
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
  List<Evento> todosLosEventos        = [];
  List<Evento> eventosDiaSeleccionado = [];
  bool isLoading = true;
  DateTime  _focusedDay  = DateTime.now();
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
      return fecha.year  == dia.year  &&
             fecha.month == dia.month &&
             fecha.day   == dia.day;
    }).toList();
  }

  Future<bool> _asegurarPermisosUbicacion() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa el GPS')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
      return null;
    }
  }

  void _abrirMapa(Evento evento) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapaModal(
        latitud:     double.parse(evento.latitud),
        longitud:    double.parse(evento.longitud),
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
          "eventos_id":          evento.eventoId,
          "empleado_evento_id":  evento.empleadoEventoId,
          "tipo":                "evento",
          "latitud_registro":    posicion.latitude.toString(),
          "longitud_registro":   posicion.longitude.toString(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
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
          "latitud_registro":  posicion.latitude.toString(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  Future<void> fetchEventos() async {
    try {
      final results = await Future.wait([
        ApiService.getEventosEmpleado(widget.empleadoId),
        ApiService.getAsistenciaActiva(),
      ]);

      final data   = results[0] as List;
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

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Center(child: CircularProgressIndicator(color: _kPrimary));

    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        _buildHeader(context, topPad),
        Expanded(
          child: Container(
            color: const Color(0xFFF4F6FA),
            child: RefreshIndicator(
              onRefresh: fetchEventos,
              color: _kPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context),
                    if (eventosDiaSeleccionado.isEmpty)
                      _buildEmptyState(context)
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Column(
                          children: eventosDiaSeleccionado
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildEventoCard(context, e),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= HEADER CON CALENDARIO =================
  Widget _buildHeader(BuildContext context, double topPad) {
    return Container(
      color: _kNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Mis Eventos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay:  DateTime.utc(2027, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventosPorDia,
                calendarStyle: CalendarStyle(
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFFEF9F27),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle:  TextStyle(color: Colors.white.withOpacity(0.85)),
                  weekendTextStyle:  TextStyle(color: Colors.white.withOpacity(0.65)),
                  outsideTextStyle:  TextStyle(color: Colors.white.withOpacity(0.25)),
                  disabledTextStyle: TextStyle(color: Colors.white.withOpacity(0.20)),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  todayTextStyle:    const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  headerPadding: const EdgeInsets.symmetric(vertical: 8),
                  titleTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  leftChevronIcon:  Icon(Icons.chevron_left,  color: Colors.white.withOpacity(0.8)),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.8)),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay  = focusedDay;
                    eventosDiaSeleccionado = _getEventosPorDia(selectedDay);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= HEADER DE SECCIÓN =================
  Widget _buildSectionHeader(BuildContext context) {
    final dia = _selectedDay ?? DateTime.now();
    const meses = [
      'enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre',
    ];
    final fechaStr = '${dia.day} de ${meses[dia.month - 1]} de ${dia.year}';
    final count = eventosDiaSeleccionado.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fechaStr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count evento${count > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ================= ESTADO VACÍO =================
  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No hay eventos para este día',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CARD DE EVENTO =================
  Widget _buildEventoCard(BuildContext context, Evento evento) {
    final bool entradaOk = evento.asistenciaRegistrada;
    final bool salidaOk  = evento.salidaRegistrada;
    final bool salidaHabilitada = entradaOk && !salidaOk;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EF), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título + badge estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    evento.titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: entradaOk
                        ? const Color(0xFFEAF3DE)
                        : const Color(0xFFE6F1FB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entradaOk ? 'Asistido' : 'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: entradaOk ? const Color(0xFF3A7D0A) : _kPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Hora
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  evento.hora,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Lugar + ver mapa
            Row(
              children: [
                Icon(Icons.place_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    evento.lugar,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
                GestureDetector(
                  onTap: () => _abrirMapa(evento),
                  child: Row(
                    children: [
                      Icon(Icons.map_rounded, size: 14, color: _kPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Ver mapa',
                        style: TextStyle(
                          color: _kPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE0E6EF)),
            const SizedBox(height: 12),

            // Botones entrada / salida
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: entradaOk ? null : () => registrarEntradaEvento(evento),
                      icon: Icon(
                        entradaOk ? Icons.check_circle_rounded : Icons.login_rounded,
                        size: 15,
                      ),
                      label: Text(entradaOk ? 'Entrada registrada' : 'Registrar entrada'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF4F6FA),
                        disabledForegroundColor: Colors.grey.shade500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: salidaHabilitada ? () => registrarSalidaEvento(evento) : null,
                      icon: Icon(
                        salidaOk ? Icons.check_circle_rounded : Icons.logout_rounded,
                        size: 15,
                      ),
                      label: Text(salidaOk ? 'Salida registrada' : 'Registrar salida'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFCEBEB),
                        foregroundColor: const Color(0xFF791F1F),
                        disabledBackgroundColor: const Color(0xFFF4F6FA),
                        disabledForegroundColor: Colors.grey.shade500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        elevation: 0,
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

// ================= MODAL MAPA =================
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
    final punto     = LatLng(latitud, longitud);
    final cardColor = Theme.of(context).cardColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: cardColor,
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
                      color: Theme.of(context).colorScheme.onSurface,
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: FlutterMap(
                options: MapOptions(initialCenter: punto, initialZoom: 16),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.hola',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: punto,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.location_pin, color: _kSalida, size: 48),
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
