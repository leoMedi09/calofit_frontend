class StaffCache {
  const StaffCache._();

  static int? _userId;
  static final Map<String, Object> _datos = {};

  static T? leer<T extends Object>(String clave, int? userId) {
    if (_userId != userId) {
      _userId = userId;
      _datos.clear();
    }
    final valor = _datos[clave];
    return valor is T ? valor : null;
  }

  static void guardar(String clave, int? userId, Object valor) {
    if (_userId != userId) {
      _userId = userId;
      _datos.clear();
    }
    _datos[clave] = valor;
  }
}
