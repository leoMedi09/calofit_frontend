import 'package:dio/dio.dart';
import '../models/auth.dart';
import '../models/user.dart';
import '../models/client.dart';
import '../models/exercise.dart';
import '../models/nutrition_plan.dart';
import '../config/api_config.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    headers: {'Content-Type': 'application/json'},
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // ✅ Asegurar que siempre usamos la última IP configurada (evita caché de Hot Reload)
      options.baseUrl = ApiConfig.baseUrl; 
      
      // 🔍 Log de debugging para ver las peticiones
      ApiConfig.printCurrentConfig();
      print('📤 ${options.method} ${options.baseUrl}${options.path}');
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      print('❌ Error en petición: ${e.message}');
      return handler.next(e);
    },
  ));

  // Autenticación
  // En ApiService.dart modifica el login para ver qué estás enviando
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      print('📤 Enviando datos de login: ${request.toJson()}'); // Verifica esto en consola
      final response = await _dio.post('/auth/login', data: request.toJson());
      print('📥 Respuesta del servidor: ${response.data}'); // ✅ LOG CRÍTICO PARA DEPURACIÓN
      return LoginResponse.fromJson(response.data);
    } on DioException catch (e) {
      print('❌ Error en login: ${e.response?.data}'); // Esto te dirá el error real del servidor
      throw Exception(e.response?.data['detail'] ?? 'Error en login');
    }
  }


  // Registro de Cliente
  Future<void> registerClient(ClientRegisterRequest request) async {
    try {
      final response = await _dio.post('/clientes/registrar', data: request.toJson());
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al registrar cliente');
      }
    } catch (e) {
      print('Error en registro: $e');
      throw Exception('Error en registro: $e');
    }
  }

  // Registro de Staff (Admin/Nutri/Coach)
  Future<void> registerStaff(Map<String, dynamic> staffData, String token) async {
    try {
      print('📤 Registrando nuevo personal: ${staffData['email']}');
      final response = await _dio.post(
        '/usuarios/registrar', 
        data: staffData,
        options: Options(headers: {'Authorization': 'Bearer $token'})
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al registrar personal');
      }
      print('✅ Personal registrado exitosamente');
    } on DioException catch (e) {
      print('❌ Error en registro de staff: ${e.response?.data}');
      throw Exception(e.response?.data['detail'] ?? 'Error al registrar personal');
    }
  }

  // Usuarios
  Future<List<User>> getUsers(String token) async {
    try {
      final response = await _dio.get('/admin/staff',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return (response.data as List).map((json) => User.fromJson(json)).toList();
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map ? e.response?.data['detail'] : e.message;
      throw Exception('Error obteniendo usuarios: $errorMessage');
    } catch (e) {
      throw Exception('Error obteniendo usuarios: $e');
    }
  }

  // Clientes
  Future<List<Client>> getClients(String token) async {
    try {
      final response = await _dio.get('/clientes/',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return (response.data as List).map((json) => Client.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error obteniendo clientes: $e');
    }
  }

  // ✅ Obtener perfil del cliente (token JWT)
  Future<Client> getClientProfile(int clientId, String token) async {
    try {
      print('🔍 Obteniendo perfil del cliente...');
      final response = await _dio.get('/clientes/perfil',
          options: Options(headers: {'Authorization': 'Bearer $token'}));

      print('✅ Perfil del cliente obtenido: ${response.data}');
      return Client.fromJson(response.data);
    } catch (e) {
      print('❌ Error obteniendo perfil del cliente: $e');
      throw Exception('Error obteniendo perfil del cliente: $e');
    }
  }

  // ✅ Actualizar contraseña de un miembro del staff (Admin only)
  Future<void> updateStaffPassword(int userId, String newPassword, String token) async {
    try {
      final response = await _dio.put(
        '/admin/staff/$userId/password',
        data: {'new_password': newPassword},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Error al actualizar contraseña');
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map ? e.response?.data['detail'] : e.message;
      throw Exception('Error: $errorMessage');
    }
  }

  // ✅ Actualizar datos de un miembro del staff (Admin only)
  Future<void> updateStaff(int userId, Map<String, dynamic> staffData, String token) async {
    try {
      print('📤 Actualizando datos de staff ID: $userId');
      final response = await _dio.put(
        '/admin/staff/$userId',
        data: staffData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Error al actualizar personal');
      }
      print('✅ Datos de staff actualizados exitosamente');
    } on DioException catch (e) {
      print('❌ Error al actualizar staff: ${e.response?.data}');
      final errorMessage = e.response?.data is Map ? e.response?.data['detail'] : e.message;
      throw Exception('Error: $errorMessage');
    }
  }

  // ✅ Obtener logs de auditoría (Admin only)
  Future<List<Map<String, dynamic>>> getAdminLogs(String token) async {
    try {
      final response = await _dio.get('/admin/logs',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map ? e.response?.data['detail'] : e.message;
      throw Exception('Error: $errorMessage');
    }
  }

  // ✅ Actualizar perfil del cliente
  Future<void> updateClient(int clientId, Client client, String token) async {
    try {
      // Usamos el método toJson del modelo que ya incluye birth_date correctamente
      final Map<String, dynamic> updateData = client.toJson();

      print('📤 Actualizando perfil del cliente...');
      print('📤 Datos: $updateData');

      final response = await _dio.put('/clientes/perfil',
          data: updateData,
          options: Options(headers: {'Authorization': 'Bearer $token'}));

      print('✅ Perfil del cliente actualizado: ${response.data}');

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar perfil');
      }
    } catch (e) {
      print('❌ Error al actualizar cliente: $e');
      throw Exception('Error al actualizar cliente: $e');
    }
  }

  // Ejercicios
  Future<List<Exercise>> getExercises(String token) async {
    try {
      final response = await _dio.get('/ejercicios/',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return (response.data as List).map((json) => Exercise.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error obteniendo ejercicios: $e');
    }
  }

  // Nutrición
  Future<List<NutritionPlan>> getNutritionPlans(String token) async {
    try {
      final response = await _dio.get('/nutricion/',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return (response.data as List).map((json) => NutritionPlan.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error obteniendo planes nutricionales: $e');
    }
  }

  // Asistente IA
  Future<String> askAssistant(String question, String token) async {
    try {
      final response = await _dio.post('/asistente/consultar',
          data: {'message': question},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return response.data['response'] ?? response.data['answer'] ?? 'Sin respuesta';
    } catch (e) {
      throw Exception('Error consultando asistente: $e');
    }
  }

  // ============ ENDPOINTS DASHBOARD ============

  Future<Map<String, dynamic>> getDailySummary(int clientId, String token) async {
    try {
      final response = await _dio.get('/dashboard/clientes/$clientId/resumen-diario',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return response.data;
    } catch (e) {
      throw Exception('Error obteniendo resumen diario: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCaloriesTrend(int clientId, String token) async {
    try {
      final response = await _dio.get('/dashboard/clientes/$clientId/calorias-tendencia',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Error obteniendo tendencia de calorías: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getWeightHistory(int clientId, String token) async {
    try {
      final response = await _dio.get('/dashboard/clientes/$clientId/peso-historial',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Error obteniendo historial de peso: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getIMCHistory(int clientId, String token) async {
    try {
      final response = await _dio.get('/dashboard/clientes/$clientId/imc-historial',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Error obteniendo historial de IMC: $e');
    }
  }

  Future<Map<String, dynamic>> getAIAnalysis(int clientId, String token) async {
    try {
      final response = await _dio.get('/dashboard/clientes/$clientId/analisis-ia',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return response.data;
    } catch (e) {
      print('⚠️ Error en análisis IA: $e');
      return {}; // Retornar mapa vacío evita que la App explote
    }
  }

  // app/lib/services/api_service.dart

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      // Usamos Query Parameters conforme a la definición: /forgot-password/request?email=...
      final response = await _dio.post(
        '/clientes/forgot-password/request',
        queryParameters: {'email': email},
      );
      print('✅ Código solicitado: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('❌ Error al solicitar código: ${e.response?.data}');
      throw Exception(e.response?.data['detail'] ?? 'Error al solicitar el código');
    }
  }

  Future<Map<String, dynamic>> validateResetCode(String email, String code, String newPassword) async {
    try {
      final response = await _dio.post(
        '/clientes/forgot-password/verify',
        queryParameters: {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
      // Si llegamos aquí, el statusCode es 200
      return {
        'success': true,
        'message': response.data['message']
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['detail'] ?? 'Error al validar el código'
      };
    }
  }

  /// 🍽️ Obtiene el plan nutricional/dieta de un cliente por su Firebase UID
  Future<Map<String, dynamic>> getDietaPorUid(String firebaseUid, String token) async {
    try {
      print('🔍 Buscando dieta automática para UID: $firebaseUid');
      final response = await _dio.get('/clientes/por-uid/$firebaseUid',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return response.data;
    } catch (e) {
      print('❌ Error obteniendo dieta por UID: $e');
      throw Exception('Error al conectar con el servicio de dietas');
    }
  }

  // ============ SISTEMA DE RECOMENDACIONES PERSONALIZADAS ============

  /// 🧠 Obtiene recomendaciones personalizadas según preferencias del usuario
  /// - Usuario nuevo: Top alimentos populares según objetivo
  /// - Usuario con historial: Sus favoritos aprendidos
  Future<Map<String, dynamic>> getRecomendacionesPersonalizadas(String token) async {
    try {
      print('🔍 Obteniendo recomendaciones personalizadas...');
      final response = await _dio.get('/nutricion/recomendaciones',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Recomendaciones obtenidas: ${response.data}');
      return response.data;
    } catch (e) {
      print('❌ Error obteniendo recomendaciones: $e');
      throw Exception('Error obteniendo recomendaciones: $e');
    }
  }

  // ============ MI BALANCE DIARIO ============

  /// 📊 Obtiene el balance calórico del día actual
  /// Incluye: resumen, alimentos registrados, ejercicios registrados
  Future<Map<String, dynamic>> getMiBalance(String token) async {
    try {
      print('🔍 Obteniendo balance del día...');
      final response = await _dio.get('/balance/hoy',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Balance obtenido: ${response.data}');
      return response.data;
    } catch (e) {
      print('❌ Error obteniendo balance: $e');
      throw Exception('Error obteniendo balance: $e');
    }
  }

  /// 🗑️ Elimina un registro de alimento o ejercicio
  /// tipo: "alimento" o "ejercicio"
  /// Recalcula automáticamente el balance después de eliminar
  Future<Map<String, dynamic>> eliminarRegistro(int registroId, String tipo, String token) async {
    try {
      print('🗑️ Eliminando registro ID: $registroId, tipo: $tipo');
      final response = await _dio.delete('/balance/registro/$registroId',
          queryParameters: {'tipo': tipo},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Registro eliminado: ${response.data}');
      return response.data;
    } catch (e) {
      print('❌ Error eliminando registro: $e');
      throw Exception('Error eliminando registro: $e');
    }
  }

  // ============ DETALLE DE ALIMENTOS CON IA ============

  /// 🍎 Obtiene información nutricional completa de un alimento usando Groq IA
  /// Genera: datos nutricionales, recomendaciones, porciones comunes, alternativas saludables
  Future<Map<String, dynamic>> getDetalleAlimento(String alimento, int porcionGramos, String token) async {
    try {
      print('🔍 Obteniendo detalle de: $alimento ($porcionGramos g)');
      final response = await _dio.post('/alimentos/detalle',
          data: {
            'alimento': alimento,
            'porcion_gramos': porcionGramos
          },
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Detalle obtenido: ${response.data['nombre']}');
      return response.data;
    } catch (e) {
      print('❌ Error obteniendo detalle de alimento: $e');
      throw Exception('Error obteniendo detalle de alimento: $e');
    }
  }

  // ============ REGISTRO INTELIGENTE POR VOZ/TEXTO (NLP) ============

  /// 🎤 Registra alimentos o ejercicios usando lenguaje natural
  /// Ejemplo: "Comí arroz con pollo" → Extrae automáticamente macros
  /// Sistema aprende preferencias automáticamente
  Future<Map<String, dynamic>> registrarPorVoz(String mensaje, String token) async {
    try {
      print('🎤 Registrando por voz: "$mensaje"');
      final response = await _dio.post('/asistente/log-inteligente',
          data: {'mensaje': mensaje},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Registro exitoso: ${response.data}');
      return response.data;
    } catch (e) {
      print('❌ Error en registro por voz: $e');
      throw Exception('Error en registro por voz: $e');
    }
  }

  /// 💬 Consulta al asistente IA con control adaptativo (fuzzy logic)
  /// El tono del asistente se adapta según adherencia y progreso
  Future<Map<String, dynamic>> consultarAsistente(String mensaje, String token) async {
    try {
      print('💬 Consultando asistente: "$mensaje"');
      final response = await _dio.post('/asistente/consultar',
          data: {'mensaje': mensaje},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Respuesta del asistente recibida');
      return response.data;
    } catch (e) {
      print('❌ Error consultando asistente: $e');
      throw Exception('Error consultando asistente: $e');
    }
  }

  // ============ ALERTAS DE SALUD (STAFF) ============

  /// 🚨 Obtiene alertas de salud de los clientes asignados (solo staff)
  Future<List<Map<String, dynamic>>> getMisAlertasClientes(String token) async {
    try {
      print('🔍 Obteniendo alertas de clientes...');
      final response = await _dio.get('/alertas/mis-clientes',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ ${response.data.length} alertas obtenidas');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      print('❌ Error obteniendo alertas: $e');
      throw Exception('Error obteniendo alertas: $e');
    }
  }

  /// 📋 Obtiene detalle de una alerta específica
  Future<Map<String, dynamic>> getDetalleAlerta(int alertaId, String token) async {
    try {
      final response = await _dio.get('/alertas/$alertaId',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return response.data;
    } catch (e) {
      throw Exception('Error obteniendo detalle de alerta: $e');
    }
  }

  /// ✅ Marca una alerta como atendida y agrega notas
  Future<void> atenderAlerta(int alertaId, String notas, String token) async {
    try {
      print('✅ Atendiendo alerta ID: $alertaId');
      await _dio.put('/alertas/$alertaId/atender',
          data: {'notas': notas},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      print('✅ Alerta atendida exitosamente');
    } catch (e) {
      print('❌ Error atendiendo alerta: $e');
      throw Exception('Error atendiendo alerta: $e');
    }
  }

  /// 📝 Actualiza una alerta existente
  Future<void> actualizarAlerta(int alertaId, Map<String, dynamic> data, String token) async {
    try {
      await _dio.put('/alertas/$alertaId/actualizar',
          data: data,
          options: Options(headers: {'Authorization': 'Bearer $token'}));
    } catch (e) {
      throw Exception('Error actualizando alerta: $e');
    }
  }

  /// 🔍 Obtiene alertas de un cliente específico (staff)
  Future<List<Map<String, dynamic>>> getAlertasCliente(int clienteId, String token) async {
    try {
      final response = await _dio.get('/alertas/cliente/$clienteId',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Error obteniendo alertas del cliente: $e');
    }
  }

  /// ✅ Suspender o reactivar miembro del staff (Admin only)
  Future<void> updateStaffStatus(int userId, String token) async {
    try {
      final response = await _dio.put(
        '/admin/staff/$userId/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Error al cambiar el estado del staff');
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map ? e.response?.data['detail'] : e.message;
      throw Exception('Error: $errorMessage');
    }
  }
}
