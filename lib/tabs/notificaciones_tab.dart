// lib/tabs/notificaciones_tab.dart
import 'package:flutter/material.dart';
import '../models/notificacion_model.dart';
import '../services/notification_service.dart';

const _kPrimary = Color(0xFF4361EE);

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
      setState(() => _notificaciones = data);
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
          backgroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.8),
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
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (_error != null) {
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

    if (_notificaciones.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: _cargar,
      color: _kPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _notificaciones.length,
        itemBuilder: (context, index) {
          final notif = _notificaciones[index];
          return Dismissible(
            key: Key(notif.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, color: Colors.white, size: 26),
                  SizedBox(height: 4),
                  Text(
                    'Archivar',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            onDismissed: (_) => _archivarNotificacion(notif),
            child: _NotificacionCard(
              notif: notif,
              onTap: () => _marcarLeida(notif),
            ),
          );
        },
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
    final colorScheme = Theme.of(context).colorScheme;

    // Fondo diferenciado leída/no leída según tema
    final bgLeida = Theme.of(context).cardColor;
    final bgNoLeida = isDark
        ? const Color(0xFF1E2A4A)
        : const Color(0xFFEEF2FF);
    final borderLeida = Theme.of(context).dividerColor;
    final borderNoLeida = isDark
        ? const Color(0xFF3D5A99)
        : const Color(0xFFC7D2FE);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.leida ? bgLeida : bgNoLeida, // ✅
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.leida ? borderLeida : borderNoLeida,
          ), // ✅
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: _kPrimary,
                size: 22,
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
                          style: TextStyle(
                            fontWeight: notif.leida
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                            color: colorScheme.onSurface, // ✅
                          ),
                        ),
                      ),
                      if (!notif.leida)
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
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.6), // ✅
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
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
    );
  }
}
