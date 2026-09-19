import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../providers/auth_provider.dart';
import '../screens/client/views/chat_screen.dart';
import '../screens/client/views/edit_profile_screen.dart';
import '../screens/client/views/mi_balance_screen.dart';
import '../screens/client/views/seguimiento_screen.dart';
import '../services/api_service.dart';
import '../services/client_cache.dart';

class ClientNav {
  const ClientNav._();

  static Future<void> ir(BuildContext context, {required int desde, required int hacia}) async {
    if (desde == hacia) return;
    if (hacia == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    final destino = await _destino(context, hacia);
    if (destino == null || !context.mounted) return;

    final ruta = MaterialPageRoute<void>(builder: (_) => destino);
    if (desde == 0) {
      await Navigator.push(context, ruta);
    } else {
      Navigator.pushReplacement(context, ruta);
    }
  }

  static Future<Widget?> _destino(BuildContext context, int indice) async {
    switch (indice) {
      case 1:
        return const ChatScreen();
      case 2:
        return const MiBalanceScreen();
      case 3:
        return const SeguimientoScreen();
      case 4:
        final perfil = await _perfil(context);
        return perfil == null ? null : EditProfileScreen(client: perfil);
    }
    return null;
  }

  static Future<Client?> _perfil(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (auth.userId == null || auth.token == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No hay una sesión activa.')));
      return null;
    }

    final api = ApiService();
    final guardado = ClientCache.perfil;
    if (guardado != null) {
      api.getClientProfile(auth.userId!, auth.token!).then((c) => ClientCache.perfil = c).catchError((_) => guardado);
      return guardado;
    }

    try {
      final perfil = await api.getClientProfile(auth.userId!, auth.token!);
      ClientCache.perfil = perfil;
      return perfil;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al obtener perfil: $e')));
      return null;
    }
  }
}

class ClientBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Color? backgroundColor;

  const ClientBottomNav({super.key, required this.selectedIndex, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      backgroundColor: backgroundColor,
      onDestinationSelected: (indice) async {
        await ClientNav.ir(context, desde: selectedIndex, hacia: indice);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Asistente',
        ),
        NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Balance',
        ),
        NavigationDestination(
          icon: Icon(Icons.trending_up_rounded),
          selectedIcon: Icon(Icons.trending_up),
          label: 'Seguimiento',
        ),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}
