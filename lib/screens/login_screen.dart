import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'qr_scanner_screen.dart';
import '../widgets/animated_glass_container.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _errorMessage;

  bool _showEmailLogin = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (res.session == null) {
        setState(() {
          _errorMessage = 'Inicio de sesión bloqueado: Correo no confirmado.';
        });
        return;
      }
      
      ref.read(authStateProvider.notifier).setLoggedIn(true);
      
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    Theme.of(context).primaryColor.withOpacity(0.3),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedGlassContainer(
                opacity: isDark ? 0.1 : 0.6,
                blur: 20,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        isDark ? 'assets/images/logo-xprinta-blanco.png' : 'assets/images/logo-xprina-azul.png',
                        height: 70,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Acceso Técnico',
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 32,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Conectando con xprinta.net',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 48),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: isDark ? Colors.white : Colors.red.shade900),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _showEmailLogin ? _buildEmailView(isDark) : _buildQrView(isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrView(bool isDark) {
    return Column(
      key: const ValueKey('qrView'),
      children: [
        SizedBox(
          width: double.infinity,
          height: 65,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const QrScannerScreen(),
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 28),
                SizedBox(width: 12),
                Text(
                  'Vincular con Código QR',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () {
            setState(() {
              _showEmailLogin = true;
              _errorMessage = null;
            });
          },
          child: const Text('Ingresar con usuario y contraseña (Avanzado)'),
        ),
      ],
    );
  }

  Widget _buildEmailView(bool isDark) {
    final textTheme = Theme.of(context).textTheme;
    final hintColor = isDark ? Colors.white70 : Colors.black54;
    final fillColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return Column(
      key: const ValueKey('emailView'),
      children: [
        TextFormField(
          controller: _emailController,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Correo Electrónico',
            labelStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(Icons.email, color: hintColor),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Ingresa tu correo';
            if (!value.contains('@')) return 'Correo no válido';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            labelStyle: TextStyle(color: hintColor),
            prefixIcon: Icon(Icons.lock, color: hintColor),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
            return null;
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isLoading ? null : _signIn,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () {
            setState(() {
              _showEmailLogin = false;
              _errorMessage = null;
            });
          },
          child: const Text('Volver a Vinculación QR (Recomendado)'),
        ),
      ],
    );
  }
}
