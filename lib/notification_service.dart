import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Inicializa el servicio de notificaciones
  static Future<void> initialize() async {
    if (_initialized) return;

    // Inicializar zonas horarias
    tz.initializeTimeZones();

    // Configuración para Android
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuración para iOS
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración general
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inicializar el plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicitar permisos
    await _requestPermissions();

    _initialized = true;
    debugPrint('📱 NotificationService inicializado correctamente');
  }

  /// Solicita permisos de notificación
  static Future<void> _requestPermissions() async {
    // Permisos para Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Permisos específicos para notificaciones programadas
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// Maneja cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notificación tocada: ${response.payload}');
    // Aquí puedes agregar lógica para navegar a la tarea específica
  }

  /// Programa una ALARMA (sonido fuerte) para una tarea
  static Future<void> scheduleTaskAlarm({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    int? minutesBefore,
    int? minutesAfter,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      DateTime notificationTime;
      String timeType;
      
      // Determinar si es antes o después
      if (minutesBefore != null) {
        notificationTime = minutesBefore == 0 
            ? taskDateTime 
            : taskDateTime.subtract(Duration(minutes: minutesBefore));
        timeType = minutesBefore == 0 ? 'ahora' : '$minutesBefore min antes';
      } else if (minutesAfter != null) {
        notificationTime = taskDateTime.add(Duration(minutes: minutesAfter));
        timeType = '$minutesAfter min después';
      } else {
        return; // No hay tiempo configurado
      }

      // Solo programar si la fecha es futura
      if (notificationTime.isBefore(DateTime.now())) {
        debugPrint('⚠️ La fecha de alarma ya pasó: $notificationTime');
        return;
      }

      // Crear el mensaje de la alarma
      String title = '🚨 ALARMA DE TAREA';
      String body;
      
      if (minutesBefore != null) {
        body = minutesBefore == 0
            ? '🔥 ¡ES HORA DE: $taskTitle!'
            : '⏰ EN $minutesBefore MIN: $taskTitle';  
      } else {
        body = '📝 DESPUÉS DE $minutesAfter MIN: $taskTitle';
      }

      // Configuración de ALARMA para Android (sonido MUY fuerte)
      final androidDetails = AndroidNotificationDetails(
        'task_alarms_loud',
        'ALARMAS DE TAREAS',
        channelDescription: 'Alarmas con sonido fuerte para tareas importantes',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        icon: '@mipmap/ic_launcher',
        fullScreenIntent: true, // Para despertar la pantalla
        category: AndroidNotificationCategory.alarm,
      );

      // Configuración de la notificación para iOS
      const DarwinNotificationDetails iosDetails = 
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      // Configuración general
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Programar la ALARMA (ID con sufijo _alarm)
      final alarmId = '${taskId}_alarm'.hashCode.abs();
      await _notifications.zonedSchedule(
        alarmId,
        title,
        body,
        tz.TZDateTime.from(notificationTime, tz.local),
        notificationDetails,
        payload: 'alarm_$taskId',
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('🚨 ALARMA programada para: $notificationTime');
      debugPrint('📝 Tarea: $taskTitle');
      if (minutesBefore != null) {
        debugPrint('⏰ Tiempo: ${minutesBefore == 0 ? "EN EL MOMENTO" : "$minutesBefore min antes"}');
      } else {
        debugPrint('⏰ Tiempo: $minutesAfter min después');
      }

    } catch (e) {
      debugPrint('❌ Error al programar alarma: $e');
    }
  }

  /// Programa una NOTIFICACIÓN (silenciosa) para una tarea
  static Future<void> scheduleTaskNotification({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    int? minutesBefore,
    int? minutesAfter,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      DateTime notificationTime;
      
      // Determinar si es antes o después
      if (minutesBefore != null) {
        notificationTime = minutesBefore == 0 
            ? taskDateTime 
            : taskDateTime.subtract(Duration(minutes: minutesBefore));
      } else if (minutesAfter != null) {
        notificationTime = taskDateTime.add(Duration(minutes: minutesAfter));
      } else {
        return; // No hay tiempo configurado
      }

      // Solo programar si la fecha es futura
      if (notificationTime.isBefore(DateTime.now())) {
        debugPrint('⚠️ La fecha de notificación ya pasó: $notificationTime');
        return;
      }

      // Crear el mensaje de la notificación
      String title = '📝 Recordatorio';
      String body;
      
      if (minutesBefore != null) {
        body = minutesBefore == 0
            ? '✨ Tarea iniciada: $taskTitle'
            : '⏰ En $minutesBefore min: $taskTitle';  
      } else {
        body = '📋 Recordatorio: $taskTitle (hace $minutesAfter min)';
      }

      // Configuración de NOTIFICACIÓN para Android (silenciosa)
      final androidDetails = AndroidNotificationDetails(
        'task_notifications_quiet',
        'Notificaciones de Tareas',
        channelDescription: 'Recordatorios silenciosos para tareas',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showWhen: true,
        enableVibration: false, // Sin vibración
        playSound: false, // Sin sonido
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
      );

      // Configuración de la notificación para iOS (silenciosa)
      const DarwinNotificationDetails iosDetails = 
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false, // Sin sonido
      );

      // Configuración general
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Programar la NOTIFICACIÓN (ID con sufijo _notification)
      final notificationId = '${taskId}_notification'.hashCode.abs();
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(notificationTime, tz.local),
        notificationDetails,
        payload: 'notification_$taskId',
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('📝 NOTIFICACIÓN programada para: $notificationTime');
      debugPrint('📝 Tarea: $taskTitle');
      if (minutesBefore != null) {
        debugPrint('⏰ Tiempo: ${minutesBefore == 0 ? "EN EL MOMENTO" : "$minutesBefore min antes"}');
      } else {
        debugPrint('⏰ Tiempo: $minutesAfter min después');
      }

    } catch (e) {
      debugPrint('❌ Error al programar notificación: $e');
    }
  }

  /// Cancela la alarma de una tarea específica
  static Future<void> cancelTaskAlarm(String taskId) async {
    if (!_initialized) return;

    try {
      final alarmId = '${taskId}_alarm'.hashCode.abs();
      await _notifications.cancel(alarmId);
      debugPrint('🗑️ Alarma cancelada para tarea ID: $taskId');
    } catch (e) {
      debugPrint('❌ Error al cancelar alarma: $e');
    }
  }

  /// Cancela la notificación de una tarea específica
  static Future<void> cancelTaskNotification(String taskId) async {
    if (!_initialized) return;

    try {
      final notificationId = '${taskId}_notification'.hashCode.abs();
      await _notifications.cancel(notificationId);
      debugPrint('🗑️ Notificación cancelada para tarea ID: $taskId');
    } catch (e) {
      debugPrint('❌ Error al cancelar notificación: $e');
    }
  }

  /// Cancela tanto alarma como notificación de una tarea
  static Future<void> cancelAllTaskNotifications(String taskId) async {
    await cancelTaskAlarm(taskId);
    await cancelTaskNotification(taskId);
    debugPrint('🗑️ Todas las notificaciones canceladas para tarea: $taskId');
  }

  /// Cancela todas las notificaciones pendientes
  static Future<void> cancelAllAlarms() async {
    if (!_initialized) return;

    try {
      await _notifications.cancelAll();
      debugPrint('🗑️ Todas las alarmas canceladas');
    } catch (e) {
      debugPrint('❌ Error al cancelar todas las alarmas: $e');
    }
  }

  /// Obtiene todas las notificaciones pendientes
  static Future<List<PendingNotificationRequest>> getPendingAlarms() async {
    if (!_initialized) return [];

    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Alarmas pendientes: ${pending.length}');
      return pending;
    } catch (e) {
      debugPrint('❌ Error al obtener alarmas pendientes: $e');
      return [];
    }
  }

  /// Muestra una notificación inmediata (para testing)
  static Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Notificaciones de Prueba',
      channelDescription: 'Canal para probar notificaciones',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      '🧪 Notificación de Prueba',
      '✅ Las notificaciones están funcionando correctamente',
      notificationDetails,
    );
  }
}