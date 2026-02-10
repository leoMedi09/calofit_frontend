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
  final ApiService _apiService = ApiService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;


  // Getters
  String? get token => _token;
  String? get userType => _userType;
  String? get userRole => _userRole;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  int? get userId => _userId;
  bool get isAuthenticated => _token != null;
  String? get userIdFirebase => _userIdFirebase;

  // lib/providers/auth_provider.dart

  Future<void> login(String email, String password, bool rememberMe, {bool isStaff = false}) async {
    try {
      String firebaseUid = "";
      debugPrint('🔥 LOGIN START: isStaff=$isStaff, email=$email');
      
      // 1️⃣ Si es CLIENTE: Intentar autenticar con Firebase primero
      if (!isStaff) {
        debugPrint('🔥 Intentando login Firebase (Modo Cliente)...');
        try {
          final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          firebaseUid = userCredential.user?.uid ?? "";
          debugPrint('🔥 Firebase UID (Cliente): $firebaseUid');
        } on FirebaseAuthException catch (e) {
          debugPrint('⚠️ Error de Firebase: ${e.code}');
          
          // FALLBACK: Si Firebase falla pero puede ser un problema temporal,
          // intentamos con el backend directamente
          if (e.code == 'user-not-found' || e.code == 'network-request-failed') {
            debugPrint('🔄 Intentando fallback: login directo con backend...');
            // Continuamos sin Firebase UID, el backend validará
          } else {
            // Para otros errores (wrong-password, etc.), sí lanzamos el error
            rethrow;
          }
        }
      } else {
        // Para staff, no usamos Firebase
        debugPrint('👥 Login de Staff: Saltando autenticación de Firebase');
      }

      // 2️⃣ Llamada a tu API FastAPI (backend valida tanto staff como client)
      final request = LoginRequest(
        email: email,
        password: password,
        rememberMe: rememberMe,
        firebaseUid: firebaseUid, // Vacío para staff
        userType: isStaff ? "staff" : "client", // ✅ Diferenciación de roles
      );
      debugPrint('📤 JSON A ENVIAR: ${request.toJson()}');

      final response = await _apiService.login(request);

      // ⚠️ VALIDACIÓN CRÍTICA: Si el token llega nulo por error de mapeo, detenemos el proceso
      if (response.token == null) {
        throw Exception('Error: El servidor no devolvió un token de acceso.');
      }

      // 3️⃣ ASIGNACIÓN DE ESTADO (Primero en memoria)
      _token = response.token;
      _userType = response.userType;
      _userRole = response.userRole;
      _userName = response.userName;
      _userEmail = response.userEmail;
      _userId = response.userId;
      _userIdFirebase = firebaseUid;

      // 4️⃣ PERSISTENCIA (En segundo plano pero esperado)
      await _saveSession(rememberMe);

      // 5️⃣ NOTIFICACIÓN (Esto dispara el redibujado de todas las pantallas)
      notifyListeners();

      debugPrint('✅ Login completado y estado notificado para: $_userName (${isStaff ? "Staff" : "Cliente"})');
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
    
    if (rememberMe) {
      if (_token != null) await prefs.setString('token', _token!);
      if (_userType != null) await prefs.setString('userType', _userType!);
      if (_userRole != null) await prefs.setString('userRole', _userRole!);
      if (_userName != null) await prefs.setString('userName', _userName!);
      if (_userEmail != null) await prefs.setString('userEmail', _userEmail!);
      if (_userId != null) await prefs.setInt('userId', _userId!);
      if (_userIdFirebase != null) await prefs.setString('userIdFirebase', _userIdFirebase!);
    } else {
      await _removeSession();
      await prefs.setBool('remember_me', false);
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
      _userIdFirebase = prefs.getString('userIdFirebase');
      
      if (_token != null && _userId != null) {
        try {
          debugPrint('🔐 Validando sesión guardada para usuario ID: $_userId');
          
          // ✅ VALIDACIÓN UNIVERSAL: Intentar obtener datos del usuario para validar el token
          if (_userType == 'staff' || _userType == 'admin') {
            // Para staff: intentar obtener la lista de usuarios
            await _apiService.getUsers(_token!);
            debugPrint('✅ Token de Staff válido');
          } else {
            // Para clientes: intentar obtener su perfil
            await _apiService.getClientProfile(_userId!, _token!);
            debugPrint('✅ Token de Cliente válido');
          }
        } catch (e) {
          debugPrint('❌ Error validando sesión: $e');
          debugPrint('🚨 Token inválido o sin conexión. Cerrando sesión...');
          
          // 🚨 FORZAR LOGOUT si el token no es válido
          await logout();
          return; // Salir para evitar notifyListeners con datos inválidos
        }
      }
    }
    notifyListeners();
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
}
