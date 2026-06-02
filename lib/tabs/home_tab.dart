// lib/tabs/home_tab.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const _kNavy   = Color(0xFF0C1A3A);
const _kBlue   = Color(0xFF185FA5);
const _kGreen  = Color(0xFF10B981);
const _kOrange = Color(0xFFF97316);
const _kPurple = Color(0xFF8B5CF6);
const _kRed    = Color(0xFFEF4444);

class HomeTab extends StatefulWidget {
  final Map<String, dynamic> empleadoData;
  final String         rol;
  final String         token;
  final int            noLeidas;
  final Function(int)  onNavegar;
  final VoidCallback   onLogout;
  final VoidCallback   onToggleTheme;
  final bool           isDark;

  const HomeTab({
    super.key,
    required this.empleadoData,
    required this.rol,
    required this.token,
    required this.noLeidas,
    required this.onNavegar,
    required this.onLogout,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _asistencia;
  bool _loadingAsistencia = true;

  @override
  void initState() {
    super.initState();
    _fetchAsistencia();
  }

  Future<void> _fetchAsistencia() async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/asistencias/activa'),
        headers: ApiService.headers,
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => _asistencia = body is Map ? Map<String, dynamic>.from(body) : null);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAsistencia = false);
  }

  // ── Helpers de empleado ────────────────────────────────────────────────────

  String get _iniciales {
    final n = widget.empleadoData['nombre']?.toString() ?? '';
    final a = widget.empleadoData['apellido']?.toString() ?? '';
    return '${n.isNotEmpty ? n[0] : ''}${a.isNotEmpty ? a[0] : ''}'.toUpperCase();
  }

  String get _nombreCompleto {
    final n = widget.empleadoData['nombre']?.toString() ?? '';
    final a = widget.empleadoData['apellido']?.toString() ?? '';
    return '$n $a'.trim();
  }

  String get _saludo {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _cargo {
    final c = widget.empleadoData['cargo'] ?? widget.empleadoData['Cargo'];
    if (c is Map) return c['nombre']?.toString() ?? '-';
    return c?.toString() ?? '-';
  }

  String get _lugar {
    final l = widget.empleadoData['lugar'] ?? widget.empleadoData['Lugar'];
    if (l is Map) return l['nombre']?.toString() ?? '-';
    return l?.toString() ?? '-';
  }

  String _formatFecha() {
    final now = DateTime.now();
    const dias   = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    const meses  = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${dias[now.weekday - 1]}, ${now.day} ${meses[now.month - 1]} ${now.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    final cardColor = isDark ? AppTheme.cardDark : Colors.white;
    final bgColor   = isDark ? AppTheme.backgroundDark : const Color(0xFFF4F6FA);
    final textMain  = isDark ? Colors.white : _kNavy;

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ══ HEADER navy con floating card ══════════════════════════
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildHeader(isDark),
                Positioned(
                  bottom: -44,
                  left: 20,
                  right: 20,
                  child: _buildStatusCard(cardColor, isDark),
                ),
              ],
            ),

            // Espacio para la card flotante
            const SizedBox(height: 62),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ══ PERFIL ═══════════════════════════════════════════
                  _buildPerfilCard(cardColor, textMain, isDark),
                  const SizedBox(height: 20),

                  // ══ ACCESOS RÁPIDOS ══════════════════════════════════
                  Text(
                    'Accesos rápidos',
                    style: TextStyle(
                      color: textMain,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAccesosGrid(isDark),
                  const SizedBox(height: 28),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: _kNavy,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Fila 1: logo + nombre app | toggle + logout
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fingerprint, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'OliverTech',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              _HeaderIconBtn(
                icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                onTap: widget.onToggleTheme,
              ),
              const SizedBox(width: 4),
              _HeaderIconBtn(
                icon: Icons.logout_rounded,
                onTap: widget.onLogout,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Fila 2: avatar + saludo + nombre
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: _kBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _iniciales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _saludo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nombreCompleto,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Fila 3: chip fecha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatFecha(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card Estado ────────────────────────────────────────────────────────────

  Widget _buildStatusCard(Color cardColor, bool isDark) {
    final bool hasRecord = _asistencia != null;
    final Color statusColor = hasRecord ? _kGreen : _kRed;
    final String statusText = hasRecord ? 'Entrada registrada' : 'Sin registro hoy';
    final IconData statusIcon =
        hasRecord ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded;

    String detalle = '';
    if (hasRecord) {
      final hora = _asistencia!['hora_entrada']?.toString() ??
          (_asistencia!['createdAt']?.toString() ?? '');
      final lugarRaw = _asistencia!['lugar'] ?? _asistencia!['Lugar'];
      final lugarNombre = (lugarRaw is Map)
          ? lugarRaw['nombre']?.toString() ?? ''
          : lugarRaw?.toString() ?? '';
      final partes = [
        if (hora.length >= 5) hora.substring(0, 5),
        if (lugarNombre.isNotEmpty) lugarNombre,
      ];
      detalle = partes.join(' · ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFE8ECF4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.09),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado de hoy',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _loadingAsistencia ? 'Verificando...' : statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (detalle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detalle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _loadingAsistencia
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: statusColor,
                    ),
                  )
                : Icon(statusIcon, color: statusColor, size: 26),
          ),
        ],
      ),
    );
  }

  // ── Card Perfil ────────────────────────────────────────────────────────────

  Widget _buildPerfilCard(Color cardColor, Color textMain, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MI PERFIL',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          _ProfileRow(
            icon:      Icons.badge_rounded,
            label:     'Cargo',
            value:     _cargo,
            color:     _kBlue,
            textColor: textMain,
          ),
          Divider(height: 20, color: Colors.grey.withOpacity(0.12)),
          _ProfileRow(
            icon:      Icons.shield_rounded,
            label:     'Rol',
            value:     widget.rol,
            color:     _kGreen,
            textColor: textMain,
          ),
          Divider(height: 20, color: Colors.grey.withOpacity(0.12)),
          _ProfileRow(
            icon:      Icons.location_on_rounded,
            label:     'Lugar',
            value:     _lugar,
            color:     _kOrange,
            textColor: textMain,
          ),
        ],
      ),
    );
  }

  // ── Grid Accesos Rápidos ───────────────────────────────────────────────────

  Widget _buildAccesosGrid(bool isDark) {
    final notifSub = widget.noLeidas > 0
        ? '${widget.noLeidas} nuevas'
        : 'Sin pendientes';

    return GridView.count(
      crossAxisCount:   2,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing:  12,
      childAspectRatio: 1.1,
      children: [
        _QuickCard(
          icon:     Icons.fingerprint_rounded,
          label:    'Asistencia',
          subtitle: 'Marcar entrada',
          color:    _kBlue,
          isDark:   isDark,
          onTap:    () => widget.onNavegar(1),
        ),
        _QuickCard(
          icon:     Icons.event_rounded,
          label:    'Eventos',
          subtitle: 'Ver próximos',
          color:    _kPurple,
          isDark:   isDark,
          onTap:    () => widget.onNavegar(2),
        ),
        _QuickCard(
          icon:     Icons.bar_chart_rounded,
          label:    'Reportes',
          subtitle: 'Mi historial',
          color:    _kGreen,
          isDark:   isDark,
          onTap:    () => widget.onNavegar(3),
        ),
        _QuickCard(
          icon:     Icons.notifications_rounded,
          label:    'Notificaciones',
          subtitle: notifSub,
          color:    _kOrange,
          isDark:   isDark,
          onTap:    () => widget.onNavegar(4),
          badge:    widget.noLeidas > 0 ? widget.noLeidas : null,
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;

  const _HeaderIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  final Color    textColor;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String       subtitle;
  final Color        color;
  final bool         isDark;
  final VoidCallback onTap;
  final int?         badge;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppTheme.cardDark : Colors.white;
    final textMain  = isDark ? Colors.white : _kNavy;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isDark ? 0.08 : 0.1),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: textMain,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
