import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController cedulaCtrl = TextEditingController();
  final TextEditingController passCtrl   = TextEditingController();
  bool loading      = false;
  bool _obscurePass = true;

  static const _navy      = Color(0xFF0C1A3A);
  static const _blue      = Color(0xFF185FA5);
  static const _bgGray    = Color(0xFFF4F6FA);
  static const _borderGray = Color(0xFFDDE2EE);

  void handleLogin() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.login(cedulaCtrl.text, passCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            empleadoData: data['empleado'],
            rol:          data['rol'],
            token:        data['token'],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Stack(
        children: [
          Container(color: _navy),

          SafeArea(
            child: Column(
              children: [

                // ══ SECCIÓN SUPERIOR (40%) — logo + branding ══════════
                Expanded(
                  flex: 40,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo 64×64 con huella
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _blue.withOpacity(0.45),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'OliverTech',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          'Sistema de Control de Asistencia',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.60),
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ══ SECCIÓN INFERIOR (60%) — formulario ═══════════════
                Expanded(
                  flex: 60,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _bgGray,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Título
                          const Text(
                            'Bienvenido',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ingresa tus credenciales para continuar',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Campo Cédula ─────────────────────────────
                          const Text(
                            'CÉDULA',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: cedulaCtrl,
                            keyboardType: TextInputType.number,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: const TextStyle(color: _navy, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Tu número de cédula',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: _blue,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _borderGray,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _blue,
                                  width: 1.5,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Campo Contraseña ─────────────────────────
                          const Text(
                            'CONTRASEÑA',
                            style: TextStyle(
                              color: _blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: passCtrl,
                            obscureText: _obscurePass,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: const TextStyle(color: _navy, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Tu contraseña',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: _blue,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _borderGray,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: _blue,
                                  width: 1.5,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Botón Iniciar sesión ─────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading ? null : handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _blue.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Link olvidé contraseña ───────────────────
                          Center(
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: _blue,
                              ),
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Footer ───────────────────────────────────
                          Center(
                            child: Text(
                              'OliverTech © 2026',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}
