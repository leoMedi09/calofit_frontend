import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Handler de mensajes recibidos cuando la app está en segundo plano o cerrada.
/// Debe ser una función de nivel superior (top-level) para que Firebase pueda
/// invocarla desde un proceso aislado.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [Background] Notificación recibida: ${message.messageId}');
}

/// Centraliza la configuración de notificaciones push (RF12):
/// permisos, obtención/registro del token FCM y visualización en foreground.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'calofit_recordatorios',
    'Recordatorios de CaloFit',
    description: 'Recordatorios diarios para registrar tus comidas y ejercicios',
    importance: Importance.high,
  );

  /// Solicita permisos, configura el canal local y conecta los listeners
  /// de mensajes en foreground. Debe llamarse una sola vez (ej. en main()).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(initSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);

    // Mostrar la notificación cuando llega con la app abierta (foreground).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  /// Obtiene el token FCM del dispositivo y lo registra en el backend
  /// asociado al usuario autenticado. Debe llamarse tras un login exitoso
  /// y al cargar una sesión persistida.
  Future<void> registrarToken(String authToken) async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;

      await ApiService().registrarFcmToken(fcmToken, authToken);
      debugPrint('✅ Token FCM registrado: $fcmToken');

      // Si el token se renueva (reinstalación, etc.), reenviarlo al backend.
      _messaging.onTokenRefresh.listen((newToken) {
        ApiService().registrarFcmToken(newToken, authToken);
        debugPrint('🔄 Token FCM renovado y reenviado: $newToken');
      });
    } catch (e) {
      debugPrint('⚠️ Error obteniendo/registrando token FCM: $e');
    }
  }
}
