import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AuthProvider with ChangeNotifier {
  // Inyectado desde main.dart para poder navegar a /login globalmente
  // (funciona incluso cuando el Consumer<AuthProvider> del home ya no está en el árbol).
  static GlobalKey<NavigatorState>? navigatorKey;
  String? _token;
  String? _userType;
  String? _userRole;
  String? _userName;
  String? _userEmail;
  int? _userId;
  String? _userIdFirebase;
  String? _profilePictureUrl;
  bool _isProfileComplete = true;
  bool _showWelcomeMessage = false;
  final ApiService _apiService = ApiService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;


  // Getters
  String? get token => _token;
  String? get userType => _userType;
  String? get userRole => _userRole;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  int? get userId => _userId;
  String? get profilePictureUrl => _profilePictureUrl;
  bool get isProfileComplete => _isProfileComplete;
  bool get isAuthenticated => _token != null;
  String? get userIdFirebase => _userIdFirebase;
  bool get showWelcomeMessage => _showWelcomeMessage;

  void consumeWelcomeMessage() {
    _showWelcomeMessage = false;
  }

  /// Login unificado:
  /// - Intenta Firebase para obtener UID si aplica.
  /// - Valida siempre contra la API con `user_type: auto`.
  /// El backend decide si el correo es cliente o staff.
  Future<void> login(String email, String password, bool rememberMe) async {
    try {
      String firebaseUid = "";
      debugPrint('🔥 LOGIN UNIFICADO: email=$email');

      // 1) Firebase para UID cuando exista usuario.
      try {
        final UserCredential userCredential =
            await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        firebaseUid = userCredential.user?.uid ?? "";
        debugPrint('🔥 Firebase UID: $firebaseUid');
      } on FirebaseAuthException catch (e) {
        debugPrint('⚠️ Firebase: ${e.code}');
        if (e.code == 'user-not-found' ||
            e.code == 'network-request-failed' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          debugPrint('🔄 Continuando sin UID; el backend validará credenciales (modo auto).');
        } else {
          rethrow;
        }
      }

      // 2) API: resolucion automatica de rol.
      final request = LoginRequest(
        email: email,
        password: password,
        rememberMe: rememberMe,
        firebaseUid: firebaseUid,
        userType: 'auto',
      );
      debugPrint('📤 JSON A ENVIAR: ${request.toJson()}');

      final response = await _apiService.login(request);

      // Validacion defensiva del token.
      if (response.token == null) {
        throw Exception('Error: El servidor no devolvió un token de acceso.');
      }

      _token = response.token;
      _userType = response.userType;
      _userRole = response.userRole;
      _userName = response.userName;
      _userEmail = response.userEmail;
      _userId = response.userId;
      _profilePictureUrl = response.profilePictureUrl;
      _isProfileComplete = response.isProfileComplete;
      debugPrint('👤 AuthProvider: profilePictureUrl recibido = $_profilePictureUrl');
      _userIdFirebase = (response.firebaseUid != null && response.firebaseUid!.isNotEmpty) 
          ? response.firebaseUid 
          : firebaseUid;

      // 4️⃣ PERSISTENCIA (En segundo plano pero esperado)
      await _saveSession(rememberMe);

      // 5️⃣ NOTIFICACIÓN (Esto dispara el redibujado de todas las pantallas)
      _showWelcomeMessage = true;
      notifyListeners();

      debugPrint('✅ Login completado: $_userName (tipo=$_userType)');
    } catch (e) {
      debugPrint('❌ Error en AuthProvider.login: $e');
      // Limpiamos datos por seguridad si algo falla a mitad de camino
      await _removeSession();
      _token = null;
      rethrow;
    }
  }


  Future<void> _saveSession(bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', rememberMe);

    if (_token != null) await prefs.setString('token', _token!);
    if (_userType != null) await prefs.setString('userType', _userType!);
    if (_userRole != null) await prefs.setString('userRole', _userRole!);
    if (_userName != null) await prefs.setString('userName', _userName!);
    if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);
    if (_userId != null) await prefs.setInt('userId', _userId!);
    await prefs.setBool('isProfileComplete', _isProfileComplete);

    // Guarda la fecha de expiración para validación local al relanzar la app.
    final expiry = DateTime.now()
        .add(rememberMe ? const Duration(days: 30) : const Duration(hours: 24));
    await prefs.setInt('token_expiry', expiry.millisecondsSinceEpoch);

    if (rememberMe) {
      if (_profilePictureUrl != null) await prefs.setString('profilePictureUrl', _profilePictureUrl!);
      if (_userIdFirebase != null) await prefs.setString('userIdFirebase', _userIdFirebase!);
    }
  }

  Future<void> _removeSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userType');
    await prefs.remove('userRole');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userId');
    await prefs.remove('userIdFirebase');
    await prefs.remove('isProfileComplete');
    await prefs.remove('token_expiry');
    await prefs.remove('remember_me');
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (!rememberMe) {
      notifyListeners();
      return;
    }

    // Verificar expiración localmente antes de mostrar la pantalla principal.
    // Esto evita que el usuario vea el dashboard con un token muerto.
    final expiryMs = prefs.getInt('token_expiry');
    if (expiryMs != null && DateTime.now().millisecondsSinceEpoch > expiryMs) {
      debugPrint('🕐 Token expirado localmente — limpiando sesión.');
      await _removeSession();
      notifyListeners();
      return;
    }

    _token = prefs.getString('token');
    _userType = prefs.getString('userType');
    _userRole = prefs.getString('userRole');
    _userName = prefs.getString('userName');
    _userEmail = prefs.getString('userEmail');
    _userId = prefs.getInt('userId');
    _profilePictureUrl = prefs.getString('profilePictureUrl');
    _userIdFirebase = prefs.getString('userIdFirebase');
    _isProfileComplete = prefs.getBool('isProfileComplete') ?? true;

    debugPrint('👤 AuthProvider: Sesión cargada. profilePictureUrl = $_profilePictureUrl');
    notifyListeners();

    if (_token != null && _userId != null) {
      _validateSessionInBackground();
    }
  }

  Future<void> _validateSessionInBackground() async {
    try {
      debugPrint('🔐 Validando sesión en segundo plano...');
      if (_userType == 'staff' || _userType == 'admin') {
        await _apiService.getUsers(_token!);
      } else {
        await _apiService.getClientProfile(_userId!, _token!);
      }
      debugPrint('✅ Sesión validada exitosamente.');
    } catch (e) {
      debugPrint('❌ Sesión inválida o expirada detectada en background: $e');
      // Detectar 401/403 correctamente tanto en DioException como en otros errores.
      // Si es error de red (timeout/sin conexión) mantenemos al usuario (modo offline).
      // Solo logout por errores de autenticación reales (no por red/timeout)
      if (e is DioException) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          debugPrint('🔐 Token inválido ($code) — cerrando sesión automáticamente.');
          await logout();
        }
        // Si es error de red/timeout: no cerrar sesión (modo offline)
      }
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('⚠️ Error cerrando sesión de Firebase (probablemente sin conexión): $e');
    }

    _token = null;
    _userType = null;
    _userRole = null;
    _userName = null;
    _userEmail = null;
    _userId = null;
    _userIdFirebase = null;
    _isProfileComplete = true;

    await _removeSession();

    debugPrint('✅ Logout completado.');
    notifyListeners();

    // Navegar a /login con navigatorKey para garantizar la redirección
    // independientemente de cuántas rutas haya en el stack.
    navigatorKey?.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
  }


  Future<void> markProfileComplete() async {
    _isProfileComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isProfileComplete', true);
    notifyListeners();
  }

  Future<void> updateUserName(String newName) async {
    _userName = newName;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('remember_me') == true) {
      await prefs.setString('userName', newName);
    }
    notifyListeners();
  }

  Future<void> updateProfilePictureUrl(String newUrl) async {
    _profilePictureUrl = newUrl;
    
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('remember_me') == true) {
      await prefs.setString('profilePictureUrl', newUrl);
    }
    
    debugPrint('✅ AuthProvider: Foto de perfil sincronizada localmente a $newUrl');
    notifyListeners();
  }

  Future<void> uploadProfilePicture(String filePath) async {
    if (_token == null || _userType == null) return;
    
    try {
      bool isStaff = (_userType == 'staff' || _userType == 'admin');
      String newUrl = await _apiService.uploadProfilePicture(_token!, filePath, isStaff);
      
      _profilePictureUrl = newUrl;
      
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('remember_me') == true) {
        await prefs.setString('profilePictureUrl', newUrl);
      }
      
      notifyListeners();
      debugPrint('✅ AuthProvider: Foto de perfil actualizada a $newUrl');
    } catch (e) {
      debugPrint('❌ AuthProvider: Error al subir foto: $e');
      rethrow;
    }
  }
}
