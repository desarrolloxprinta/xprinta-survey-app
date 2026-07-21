import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Notificaciones Locales
  await NotificationService().init();

  // Inicializar Supabase
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: XprintaSurveyApp(),
    ),
  );
}

// Cliente global de Supabase
final supabase = Supabase.instance.client;

// Riverpod Provider para el Modo Oscuro/Claro (por defecto Light Mode)
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    state = mode;
  }
  
  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

class XprintaSurveyApp extends ConsumerWidget {
  const XprintaSurveyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Xprinta Survey',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      home: const AuthWrapper(),
    );
  }
}

// Proveedor de estado de autenticación (Riverpod moderno)
class AuthNotifier extends Notifier<bool> {
  @override
  bool build() {
    return supabase.auth.currentSession != null;
  }

  void setLoggedIn(bool value) {
    state = value;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escucha el estado de autenticación reactivamente
    final isLoggedIn = ref.watch(authStateProvider);

    if (isLoggedIn) {
      return const DashboardScreen();
    } else {
      return const LoginScreen();
    }
  }
}
