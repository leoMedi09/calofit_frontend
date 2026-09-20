import '../models/client.dart';

class ClientCache {
  const ClientCache._();

  static int? _userId;
  static final List<void Function()> _alCambiarUsuario = [];

  static Map<String, dynamic>? semanaActual;
  static Map<String, dynamic>? racha;
  static Map<String, dynamic>? checkIn;
  static Client? perfil;
  static bool perfilVisto = false;

  static void alCambiarUsuario(void Function() accion) => _alCambiarUsuario.add(accion);

  static void bindUser(int? userId) {
    if (_userId == userId) return;
    _userId = userId;
    semanaActual = null;
    racha = null;
    checkIn = null;
    perfil = null;
    perfilVisto = false;
    for (final accion in List.of(_alCambiarUsuario)) {
      accion();
    }
  }

  static void clear() => bindUser(null);
}
