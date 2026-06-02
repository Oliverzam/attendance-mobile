// lib/tabs/reportes_tab.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' show max;
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

const _kPrimary = Color(0xFF185FA5);
const _kNavy = Color(0xFF0C1A3A);
const _kVerde = Color(0xFF3B6D11);
const _kMorado = Color(0xFF534AB7);

class ReportesTab extends StatefulWidget {
  final String token;

  const ReportesTab({super.key, required this.token});

  @override
  State<ReportesTab> createState() => _ReportesTabState();
}

class _ReportesTabState extends State<ReportesTab> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();

  List<dynamic> _asistencias = [];
  Map<String, dynamic> _resumen = {};
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  String _formatFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final desde = _formatFecha(_desde);
      final hasta = _formatFecha(_hasta);
      final base = ApiService.baseUrl;

      final results = await Future.wait([
        http.get(
          Uri.parse('$base/api/asistencias/mis?desde=$desde&hasta=$hasta'),
          headers: _headers,
        ),
        http.get(
          Uri.parse(
            '$base/api/asistencias/mi-resumen?desde=$desde&hasta=$hasta',
          ),
          headers: _headers,
        ),
      ]);

      final resList = results[0];
      final resResumen = results[1];

      if (resList.statusCode == 200 && resResumen.statusCode == 200) {
        final todas = List<dynamic>.from(jsonDecode(resList.body));
        setState(() {
          _asistencias = todas.where((a) => a['hora_salida'] != null).toList();
          _resumen = jsonDecode(resResumen.body);
        });
      } else {
        setState(() => _error = 'Error al cargar los datos');
      }
    } catch (e) {
      print('Error reportes: $e');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, bool esDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _desde : _hasta,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) {
      setState(() {
        if (esDesde)
          _desde = picked;
        else
          _hasta = picked;
      });
      _cargar();
    }
  }

  String _calcularHoras(String? entrada, String? salida) {
    if (entrada == null || salida == null) return '-';
    final e = DateTime.parse(entrada);
    final s = DateTime.parse(salida);
    final diff = s.difference(e);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _formatHora(String? fecha) {
    if (fecha == null) return '-';
    final d = DateTime.parse(fecha).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatFechaLegible(String? fecha) {
    if (fecha == null) return '-';
    final d = DateTime.parse(fecha).toLocal();
    const meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  int _diasPeriodo() => _hasta.difference(_desde).inDays + 1;

  double _pctAsistencia() {
    final dias = (_resumen['diaria']?['totalRegistros'] ?? 0) as num;
    final laborables = max(1, (_diasPeriodo() * 5 / 7).ceil());
    return (dias / laborables * 100).clamp(0, 100).toDouble();
  }

  double _pctPuntualidad() {
    if (_asistencias.isEmpty) return 0;
    final completas = _asistencias.where((a) {
      if (a['hora_entrada'] == null || a['hora_salida'] == null) return false;
      final e = DateTime.parse(a['hora_entrada'] as String);
      final s = DateTime.parse(a['hora_salida'] as String);
      return s.difference(e).inMinutes >= 7 * 60;
    }).length;
    return (completas / _asistencias.length * 100).clamp(0, 100).toDouble();
  }

  double _pctEventos() {
    final eventos = (_resumen['evento']?['totalRegistros'] ?? 0) as num;
    final semanas = max(1, (_diasPeriodo() / 7).ceil());
    return (eventos / semanas * 100).clamp(0, 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6FA),
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: _buildError(),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              color: _kPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgreso(context),
                    const SizedBox(height: 16),
                    _buildListaRegistros(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final diaria = _resumen['diaria'] ?? {};
    final evento = _resumen['evento'] ?? {};
    final horas = diaria['horas'] ?? 0;
    final minutos = (diaria['minutos'] ?? 0).toString().padLeft(2, '0');
    final diasTrabajados = diaria['totalRegistros'] ?? 0;
    final eventosAsistidos = evento['totalRegistros'] ?? 0;

    return Container(
      color: _kNavy,
      padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Mis Reportes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fila de KPIs
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card azul principal
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HORAS TRABAJADAS',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${horas}h',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '$minutos min adicionales',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // KPIs pequeños
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$diasTrabajados',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'Días trabajados',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$eventosAsistidos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'Eventos',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Filtros de fecha
          Row(
            children: [
              Expanded(
                child: _FechaBtn(
                  label: 'Desde',
                  fecha: _formatFechaLegible(_desde.toIso8601String()),
                  onTap: () => _seleccionarFecha(context, true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FechaBtn(
                  label: 'Hasta',
                  fecha: _formatFechaLegible(_hasta.toIso8601String()),
                  onTap: () => _seleccionarFecha(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgreso(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E6EF), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progreso del mes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 16),
            _BarraProgreso(
              label: 'Asistencia diaria',
              porcentaje: _pctAsistencia(),
              color: _kPrimary,
            ),
            const SizedBox(height: 14),
            _BarraProgreso(
              label: 'Puntualidad',
              porcentaje: _pctPuntualidad(),
              color: _kVerde,
            ),
            const SizedBox(height: 14),
            _BarraProgreso(
              label: 'Eventos completados',
              porcentaje: _pctEventos(),
              color: _kMorado,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaRegistros(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos registros',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 12),
          if (_asistencias.isEmpty)
            _buildEmpty()
          else
            ..._asistencias.map((a) => _buildCard(context, a)),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> a) {
    final tipo = a['tipo'] ?? 'diaria';
    final esEvento = tipo == 'evento';
    final accentColor = esEvento ? _kMorado : _kPrimary;
    final badgeBg = esEvento
        ? const Color(0xFFF0EEFF)
        : const Color(0xFFE6F1FB);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6EF), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatFechaLegible(a['hora_entrada']),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kNavy,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          esEvento ? 'Evento' : 'Diaria',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoItem(
                          icono: Icons.login_rounded,
                          label: 'Entrada',
                          valor: _formatHora(a['hora_entrada']),
                          color: const Color(0xFF10B981),
                          textColor: _kNavy,
                        ),
                      ),
                      Expanded(
                        child: _InfoItem(
                          icono: Icons.logout_rounded,
                          label: 'Salida',
                          valor: _formatHora(a['hora_salida']),
                          color: const Color(0xFFEF4444),
                          textColor: _kNavy,
                        ),
                      ),
                      Expanded(
                        child: _InfoItem(
                          icono: Icons.timer_rounded,
                          label: 'Total',
                          valor: _calcularHoras(
                            a['hora_entrada'],
                            a['hora_salida'],
                          ),
                          color: const Color(0xFFF59E0B),
                          textColor: _kNavy,
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

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'Sin registros en este período',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          const Text(
            'No se pudieron cargar\nlos reportes',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;

  const _MiniKpi({
    required this.icono,
    required this.valor,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  etiqueta,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  final String label;
  final double porcentaje;
  final Color color;

  const _BarraProgreso({
    required this.label,
    required this.porcentaje,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = porcentaje.round();
    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: porcentaje / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFF0F3F8),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _FechaBtn extends StatelessWidget {
  final String label;
  final String fecha;
  final VoidCallback onTap;

  const _FechaBtn({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
                Text(
                  fecha,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

class _InfoItem extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final Color color;
  final Color textColor;

  const _InfoItem({
    required this.icono,
    required this.label,
    required this.valor,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
