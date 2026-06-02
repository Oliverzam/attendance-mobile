// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../tabs/home_tab.dart';
import '../tabs/asistencia_tab.dart';
import '../tabs/eventos_tab.dart';
import '../tabs/reportes_tab.dart';
import '../tabs/notificaciones_tab.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> empleadoData;
  final String rol;
  final String token;

  const HomeScreen({
    super.key,
    required this.empleadoData,
    required this.rol,
    required this.token,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _noLeidas    = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.authToken = widget.token;
    _contarNoLeidas();

    FirebaseMessaging.onMessage.listen((_) => _contarNoLeidas());
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _contarNoLeidas());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _contarNoLeidas();
  }

  Future<void> _contarNoLeidas() async {
    try {
      final notifs = await NotificationService.obtenerNotificaciones(
        widget.empleadoData['id'],
      );
      setState(() => _noLeidas = notifs.where((n) => !n.leida).length);
    } catch (_) {}
  }

  void handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark =
            themeProvider.themeMode == ThemeMode.dark ||
            (themeProvider.themeMode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        final List<Widget> tabs = [
          HomeTab(
            empleadoData: widget.empleadoData,
            rol:          widget.rol,
            token:        widget.token,
            noLeidas:     _noLeidas,
            onNavegar:    (i) => setState(() => _currentIndex = i),
            onLogout:     handleLogout,
            onToggleTheme: () => themeProvider.toggleTheme(!isDark),
            isDark:       isDark,
          ),
          AsistenciaTab(empleadoId: widget.empleadoData['id']),
          EventosTab(empleadoId: widget.empleadoData['id']),
          ReportesTab(token: widget.token),
          NotificacionesTab(
            token:                  widget.token,
            empleadoId:             widget.empleadoData['id'],
            onNotificacionesLeidas: _contarNoLeidas,
          ),
        ];

        return Scaffold(
          body: tabs[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex:        _currentIndex,
            type:                BottomNavigationBarType.fixed,
            selectedItemColor:   const Color(0xFF185FA5),
            unselectedItemColor: const Color(0xFFB4B2A9),
            backgroundColor:     isDark ? AppTheme.cardDark : Colors.white,
            elevation:           8,
            selectedLabelStyle:   const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            onTap: (i) {
              setState(() => _currentIndex = i);
              if (i == 4) _contarNoLeidas();
            },
            items: [
              const BottomNavigationBarItem(
                icon:  Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon:  Icon(Icons.fingerprint_rounded),
                label: 'Asistencia',
              ),
              const BottomNavigationBarItem(
                icon:  Icon(Icons.event_rounded),
                label: 'Eventos',
              ),
              const BottomNavigationBarItem(
                icon:  Icon(Icons.bar_chart_rounded),
                label: 'Reportes',
              ),
              BottomNavigationBarItem(
                label: 'Notif.',
                icon: Badge(
                  isLabelVisible: _noLeidas > 0,
                  label: Text('$_noLeidas'),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.notifications_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
