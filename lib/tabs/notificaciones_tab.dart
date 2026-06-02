// lib/tabs/notificaciones_tab.dart
import 'package:flutter/material.dart';
import '../models/notificacion_model.dart';
import '../services/notification_service.dart';

const _kPrimary = Color(0xFF185FA5);
const _kNavy = Color(0xFF0C1A3A);

class NotificacionesTab extends StatefulWidget {
  final String token;
  final int empleadoId;
  final VoidCallback? onNotificacionesLeidas;

  const NotificacionesTab({
    super.key,
    required this.token,
    required this.empleadoId,
    this.onNotificacionesLeidas,
  });

  @override
  State<NotificacionesTab> createState() => _NotificacionesTabState();
}

class _NotificacionesTabState extends State<NotificacionesTab> {
  List<NotificacionModel> _notificaciones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('🔑 TOKEN: ${widget.token}');
    print('👤 EMPLEADO ID: ${widget.empleadoId}');
    NotificationService.authToken = widget.token;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      setState(() {
        _cargando = true;
        _error = null;
      });
      final data = await NotificationService.obtenerNotificaciones(
        widget.empleadoId,
      );
      print('Notificaciones cargadas: ${data.length}');
      for (final n in data) {
        print('  id:${n.id} leida:${n.leida} titulo:"${n.titulo}"');
      }
      setState(() => _notificaciones = data);
      print('_notificaciones en state: ${_notificaciones.length}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _archivarNotificacion(NotificacionModel notif) async {
    try {
      await NotificationService.archivarNotificacion(
        widget.empleadoId,
        notif.notificacionId,
      );
      setState(() => _notificaciones.removeWhere((n) => n.id == notif.id));
      widget.onNotificacionesLeidas?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notificación archivada'),
          backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _cargar();
    }
  }

  Future<void> _marcarLeida(NotificacionModel notif) async {
    if (notif.leida) return;
    try {
      await NotificationService.marcarComoRecibida(
        widget.empleadoId,
        notif.notificacionId,
      );
      setState(() {
        final index = _notificaciones.indexWhere((n) => n.id == notif.id);
        if (index != -1) {
          _notificaciones[index] = NotificacionModel(
            id: notif.id,
            notificacionId: notif.notificacionId,
            titulo: notif.titulo,
            mensaje: notif.mensaje,
            fechaEnvio: notif.fechaEnvio,
            estado: 'recibido',
          );
        }
      });
      widget.onNotificacionesLeidas?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final noLeidas = _notificaciones.where((n) => !n.leida).length;

    return Container(
      color: _kNavy,
      padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 18),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'Notificaciones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (noLeidas > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$noLeidas',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_error != null) return _buildError(context);
    if (_notificaciones.isEmpty) return _buildEmpty(context);

    return RefreshIndicator(
      onRefresh: _cargar,
      color: _kPrimary,
      child: _buildLista(context),
    );
  }

  Widget _buildLista(BuildContext context) {
    final noLeidas = _notificaciones.where((n) => !n.leida).toList();
    final leidas = _notificaciones.where((n) => n.leida).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        if (noLeidas.isNotEmpty) ...[
          const _SectionLabel(label: 'NUEVA'),
          const SizedBox(height: 8),
          ...noLeidas.map((n) => _buildDismissible(n)),
        ],
        if (leidas.isNotEmpty) ...[
          if (noLeidas.isNotEmpty) const SizedBox(height: 12),
          const _SectionLabel(label: 'ANTERIORES'),
          const SizedBox(height: 8),
          ...leidas.map((n) => _buildDismissible(n)),
        ],
      ],
    );
  }

  Widget _buildDismissible(NotificacionModel notif) {
    return Dismissible(
      key: Key(notif.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              'Archivar',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _archivarNotificacion(notif),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _NotificacionCard(
          notif: notif,
          onTap: () => _marcarLeida(notif),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aquí aparecerán tus alertas y avisos',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No se pudieron cargar\nlas notificaciones',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              fontSize: 16,
            ),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NotificacionCard extends StatelessWidget {
  final NotificacionModel notif;
  final VoidCallback onTap;

  const _NotificacionCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return notif.leida
        ? _buildLeida(context)
        : _buildNoLeida(isDark);
  }

  Widget _buildNoLeida(bool isDark) {
    final bg = isDark ? const Color(0xFF1E2A4A) : const Color(0xFFEEF2FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _kNavy,
                                  ),
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: _kPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif.mensaje,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF444444),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif.tiempoRelativo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildLeida(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E6EF), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.mensaje,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888780),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.tiempoRelativo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB4B2A9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
