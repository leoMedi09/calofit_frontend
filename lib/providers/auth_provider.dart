import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userType;
  String? _userRole;
  String? _userName;
  String? _userEmail;
  int? _userId;
  String? _userIdFirebase;
  String? _profilePictureUrl; // ✅ Añadido para el rediseño premium
  bool _isProfileComplete = true; // 🌟 Nuevo: Control de Onboarding
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

  // lib/providers/auth_provider.dart

  /// Login unificado: intenta Firebase (clientes) y siempre valida en API con `user_type: auto`.
  /// El backend decide si el correo es Client o User (staff) según la base de datos.
  Future<void> login(String email, String password, bool rememberMe) async {
    try {
      String firebaseUid = "";
      debugPrint('🔥 LOGIN UNIFICADO: email=$email');

      // 1️⃣ Firebase: útil para clientes (UID para sincronizar). Staff suele no existir en Firebase → se ignora.
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

      // 2️⃣ API: resolución automática de rol
      final request = LoginRequest(
        email: email,
        password: password,
        rememberMe: rememberMe,
        firebaseUid: firebaseUid,
        userType: 'auto',
      );
      debugPrint('📤 JSON A ENVIAR: ${request.toJson()}');

      final response = await _apiService.login(request);

      // ⚠️ VALIDACIÓN CRÍTICA: Si el token llega nulo por error de mapeo, detenemos el proceso
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
    
    // Siempre guardamos el token básico para evitar que el usuario sea expulsado por error
    // pero respetamos el rememberMe para la carga automática del perfil completo
    if (_token != null) await prefs.setString('token', _token!);
    if (_userType != null) await prefs.setString('userType', _userType!);
    if (_userRole != null) await prefs.setString('userRole', _userRole!);
    if (_userName != null) await prefs.setString('userName', _userName!);
    if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);
    if (_userId != null) await prefs.setInt('userId', _userId!);
    await prefs.setBool('isProfileComplete', _isProfileComplete);
    
    if (rememberMe) {
      if (_profilePictureUrl != null) await prefs.setString('profilePictureUrl', _profilePictureUrl!);
      if (_userIdFirebase != null) await prefs.setString('userIdFirebase', _userIdFirebase!);
    } else {
      // Si no marcó recordarme, al menos mantenemos la sesión por 24 horas (duración del token)
      // pero podríamos limpiar datos sensibles si fuera necesario.
      // Por ahora, priorizamos que NO lo bote de la sesión.
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
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    bool rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe) {
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
      
      // ✅ NOTIFICAR AL INICIO: Permitir que la App cargue la UI al instante
      notifyListeners();

      // ✅ VALIDACIÓN ASÍNCRONA (Background): Validar en segundo plano para no bloquear el arranque
      if (_token != null && _userId != null) {
        _validateSessionInBackground();
      }
    } else {
      notifyListeners();
    }
  }

  // Nueva función para validación silenciosa
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
      // Solo si el error es 401/403 (Autenticación), cerramos sesión. 
      // Si es error de red (Timeout), mantenemos al usuario (modo offline/resiliente).
      if (e.toString().contains('401') || e.toString().contains('403')) {
        await logout();
      }
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('⚠️ Error cerrando sesión de Firebase (probablemente sin conexión): $e');
      // Continuar con el logout de todas formas
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
    
    debugPrint('✅ Logout completado. Usuario debe ser redirigido al login.');
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
