import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/balance_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_main_screen.dart';
import 'screens/staff/staff_main_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_code_screen.dart';
import 'screens/splash_screen.dart';
import 'app_theme.dart';

import 'screens/client/onboarding_profile_screen.dart';
import 'models/client.dart';
import 'services/api_service.dart';

import 'widgets/app_loading.dart';

import 'services/route_observer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class OnboardingProfileLoader extends StatelessWidget {
  const OnboardingProfileLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = ApiService();

    return FutureBuilder<Client>(
      future: api.getClientProfile(auth.userId!, auth.token!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: AppLoading(message: 'Preparando tu configuración inicial...'));
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text('Error al cargar tu perfil'),
                  TextButton(
                    onPressed: () => auth.logout(),
                    child: const Text('Cerrar sesión y reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        return OnboardingProfileScreen(client: snapshot.data!);
      },
    );
  }
}

Future<AuthProvider> _inicializarApp() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await NotificationService.instance.initialize();
    }
  } catch (e) {
    debugPrint("Error al inicializar Firebase: $e");
  }

  final authProvider = AuthProvider();
  AuthProvider.navigatorKey = navigatorKey;
  try {
    await authProvider.loadToken();
  } catch (e) {
    debugPrint("Error al cargar la sesión guardada: $e");
  }
  return authProvider;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static const _splashMinimo = Duration(milliseconds: 1200);

  late final Future<AuthProvider> _inicio = _iniciar();

  Future<AuthProvider> _iniciar() async {
    final resultados = await Future.wait<Object?>([_inicializarApp(), Future<void>.delayed(_splashMinimo)]);
    return resultados[0] as AuthProvider;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthProvider>(
      future: _inicio,
      builder: (context, snapshot) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: snapshot.hasData
              ? MyApp(key: const ValueKey('app'), authProvider: snapshot.data!)
              : const MaterialApp(
                  key: ValueKey('splash'),
                  debugShowCheckedModeBanner: false,
                  home: SplashScreen(),
                ),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => BalanceProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        title: 'CaloFit',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'ES'),
        ],
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isAuthenticated) return const LoginScreen();

            final isStaff = (auth.userType == 'staff' || auth.userType == 'admin');

            if (isStaff) return const StaffMainScreen();

            if (!auth.isProfileComplete) {
              return const OnboardingProfileLoader();
            }

            return const ClientMainScreen();
          },
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const ClientMainScreen(),
          '/staff-main': (context) => const StaffMainScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/verify-code': (context) => const VerifyCodeScreen(),
        },
      ),
    );
  }
}
