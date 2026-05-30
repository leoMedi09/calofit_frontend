import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/balance_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_main_screen.dart';
import 'screens/staff/staff_main_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_code_screen.dart';
import 'app_theme.dart';

import 'screens/client/onboarding_profile_screen.dart';
import 'models/client.dart';
import 'services/api_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ... (main remains same)

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
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Preparando tu configuración inicial...', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
          );
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Error al inicializar Firebase: $e");
  }

  final authProvider = AuthProvider();
  await authProvider.loadToken();
  runApp(MyApp(authProvider: authProvider));
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