import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [Background] Notificación recibida: ${message.messageId}');
}

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

  Future<void> initialize() async {
    if (kIsWeb) return;
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

  Future<void> registrarToken(String authToken) async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;

      await ApiService().registrarFcmToken(fcmToken, authToken);
      debugPrint('✅ Token FCM registrado: $fcmToken');

      _messaging.onTokenRefresh.listen((newToken) {
        ApiService().registrarFcmToken(newToken, authToken);
        debugPrint('🔄 Token FCM renovado y reenviado: $newToken');
      });
    } catch (e) {
      debugPrint('⚠️ Error obteniendo/registrando token FCM: $e');
    }
  }
}
