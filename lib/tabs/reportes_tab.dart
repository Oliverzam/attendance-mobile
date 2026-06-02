// lib/tabs/reportes_tab.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ReportesTab extends StatefulWidget {
  final String token;

  const ReportesTab({super.key, required this.token});

  @override
  State<ReportesTab> createState() => _ReportesTabState();
}

class _ReportesTabState extends State<ReportesTab> {
  static const String baseUrl =
      'http://192.168.1.2:3000'; // Cambia esto por tu IP local o ngrok

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

      final resList = await http.get(
        Uri.parse('$baseUrl/api/asistencias/mis?desde=$desde&hasta=$hasta'),
        headers: _headers,
      );
      final resResumen = await http.get(
        Uri.parse(
          '$baseUrl/api/asistencias/mi-resumen?desde=$desde&hasta=$hasta',
        ),
        headers: _headers,
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4361EE)),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _cargar,
              color: const Color(0xFF4361EE),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFiltros(context),
                  const SizedBox(height: 16),
                  _buildKPIs(context),
                  const SizedBox(height: 16),
                  _asistencias.isEmpty
                      ? _buildEmpty()
                      : Column(
                          children: _asistencias
                              .map((a) => _buildCard(context, a))
                              .toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildFiltros(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FechaBtn(
            label: 'Desde',
            fecha: _formatFechaLegible(_desde.toIso8601String()),
            onTap: () => _seleccionarFecha(context, true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FechaBtn(
            label: 'Hasta',
            fecha: _formatFechaLegible(_hasta.toIso8601String()),
            onTap: () => _seleccionarFecha(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildKPIs(BuildContext context) {
    final diaria = _resumen['diaria'] ?? {};
    final evento = _resumen['evento'] ?? {};

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icono: Icons.schedule_rounded,
                valor:
                    '${diaria['horas'] ?? 0}h ${(diaria['minutos'] ?? 0).toString().padLeft(2, '0')}m',
                etiqueta: 'Horas diarias',
                color: const Color(0xFF4361EE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icono: Icons.calendar_today_rounded,
                valor: '${diaria['totalRegistros'] ?? 0}',
                etiqueta: 'Días trabajados',
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icono: Icons.event_rounded,
                valor: '${evento['totalRegistros'] ?? 0}',
                etiqueta: 'Eventos asistidos',
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                icono: Icons.timer_rounded,
                valor:
                    '${evento['horas'] ?? 0}h ${(evento['minutos'] ?? 0).toString().padLeft(2, '0')}m',
                etiqueta: 'Horas en eventos',
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> a) {
    final tipo = a['tipo'] ?? 'diaria';
    final esEvento = tipo == 'evento';
    final cardColor = Theme.of(context).cardColor; // ✅
    final textSecondary = Theme.of(
      context,
    ).colorScheme.onSurface.withOpacity(0.5); // ✅
    final textPrimary = Theme.of(context).colorScheme.onSurface; // ✅
    final borderColor = Theme.of(context).dividerColor; // ✅

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor, // ✅
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor), // ✅
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: esEvento
                      ? const Color(0xFF8B5CF6).withOpacity(0.12)
                      : const Color(0xFF4361EE).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      esEvento ? Icons.event_rounded : Icons.work_rounded,
                      size: 14,
                      color: esEvento
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF4361EE),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      esEvento ? 'Evento' : 'Diaria',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: esEvento
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF4361EE),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatFechaLegible(a['hora_entrada']),
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ), // ✅
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icono: Icons.login_rounded,
                  label: 'Entrada',
                  valor: _formatHora(a['hora_entrada']),
                  color: const Color(0xFF10B981),
                  textColor: textPrimary, // ✅
                ),
              ),
              Expanded(
                child: _InfoItem(
                  icono: Icons.logout_rounded,
                  label: 'Salida',
                  valor: _formatHora(a['hora_salida']),
                  color: const Color(0xFFEF4444),
                  textColor: textPrimary, // ✅
                ),
              ),
              Expanded(
                child: _InfoItem(
                  icono: Icons.timer_rounded,
                  label: 'Horas',
                  valor: _calcularHoras(a['hora_entrada'], a['hora_salida']),
                  color: const Color(0xFFF59E0B),
                  textColor: textPrimary, // ✅
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60),
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
              backgroundColor: const Color(0xFF4361EE),
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

class _KpiCard extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color color;

  const _KpiCard({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // ✅
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor), // ✅
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
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
    final textPrimary = Theme.of(context).colorScheme.onSurface; // ✅

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, // ✅
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor), // ✅
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Color(0xFF4361EE),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  fecha,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ), // ✅
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
  final Color textColor; // ✅

  const _InfoItem({
    required this.icono,
    required this.label,
    required this.valor,
    required this.color,
    required this.textColor, // ✅
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ), // ✅
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
