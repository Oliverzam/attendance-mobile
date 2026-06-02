class NotificacionModel {
  final int id;
  final int notificacionId;
  final String titulo;
  final String mensaje;
  final DateTime fechaEnvio;
  final String estado; // 'enviado' | 'recibido' | 'fallido'

  NotificacionModel({
    required this.id,
    required this.notificacionId,
    required this.titulo,
    required this.mensaje,
    required this.fechaEnvio,
    required this.estado,
  });

  bool get leida => estado == 'recibido';

  factory NotificacionModel.fromMap(Map<String, dynamic> map) {
    final notif = map['notificacion'];
    return NotificacionModel(
      id: map['id'],
      notificacionId: map['notificacion_id'],
      titulo: notif['titulo'] ?? '',
      mensaje: notif['mensaje'] ?? '',
      fechaEnvio: () {
        final raw = (notif['fecha_envio'] as String).trim().replaceFirst(
          ' ',
          'T',
        );
        final normalized = raw.endsWith('Z') ? raw : '${raw}Z';
        return DateTime.parse(normalized).toLocal();
      }(),
      estado: map['estado'] ?? 'enviado',
    );
  }

  String get tiempoRelativo {
    final diff = DateTime.now().difference(fechaEnvio);
    print(
      '⏳ Calculando tiempo relativo para: ${fechaEnvio} - Diferencia: ${diff.inSeconds} segundos',
    );
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return 'hace ${diff.inDays} días';
  }
}
