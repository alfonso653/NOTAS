import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'real_alarm_service.dart';

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

    try {
      // Inicializar zonas horarias de forma más segura
      try {
        tz.initializeTimeZones();
        debugPrint('✅ Zonas horarias inicializadas');
      } catch (e) {
        debugPrint('⚠️ Error al inicializar zonas horarias: $e');
        // Continuar, algunas versiones no necesitan inicialización explícita
      }

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
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('🔧 Plugin de notificaciones inicializado: $initialized');

      // Solicitar permisos
      await _requestPermissions();

      // Configurar canales de notificación específicos
      await _setupNotificationChannels();

      _initialized = true;
      debugPrint('📱 NotificationService inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error crítico al inicializar NotificationService: $e');
      debugPrint('📍 Stack trace: ${e.toString()}');
      // No relanzar el error para evitar que la app se cierre
    }
  }

  /// Solicita permisos de notificación
  static Future<void> _requestPermissions() async {
    try {
      // Permisos para Android 13+
      try {
        if (await Permission.notification.isDenied) {
          final result = await Permission.notification.request();
          debugPrint('📱 Permiso de notificaciones: $result');
        } else {
          debugPrint('✅ Permisos de notificación ya concedidos');
        }
      } catch (e) {
        debugPrint('⚠️ Error al verificar permisos de notificación: $e');
      }

      // Permisos específicos para notificaciones programadas
      try {
        final androidPlugin =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final notificationPermission =
              await androidPlugin.requestNotificationsPermission();
          debugPrint(
              '📱 Permiso de notificaciones Android: $notificationPermission');

          final alarmPermission =
              await androidPlugin.requestExactAlarmsPermission();
          debugPrint('📱 Permiso de alarmas exactas Android: $alarmPermission');
        }
      } catch (e) {
        debugPrint('⚠️ Error al solicitar permisos específicos de Android: $e');
      }
    } catch (e) {
      debugPrint('❌ Error general al solicitar permisos: $e');
      // No relanzar el error para evitar que la app se cierre
    }
  }

  /// Maneja cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('🔔 Notificación tocada: ${response.payload}');
      // Aquí puedes agregar lógica para navegar a la tarea específica
    } catch (e) {
      debugPrint('❌ Error al manejar notificación tocada: $e');
    }
  }

  /// Configura los canales de notificación específicos
  static Future<void> _setupNotificationChannels() async {
    try {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // 🚨 Canal para ALARMAS (sonido fuerte como despertador)
        const AndroidNotificationChannel alarmChannel =
            AndroidNotificationChannel(
          'task_alarms_loud',
          '🚨 ALARMAS DESPERTADOR',
          description:
              'Alarmas que despiertan como un despertador real para tareas importantes',
          importance: Importance.max,
          showBadge: true,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          // Configuración específica para alarmas - usar sonido predeterminado
          audioAttributesUsage: AudioAttributesUsage.alarm,
        );

        // 🔕 Canal para NOTIFICACIONES (silenciosas)
        const AndroidNotificationChannel notificationChannel =
            AndroidNotificationChannel(
          'task_notifications_silent',
          '🔕 NOTIFICACIONES SILENCIOSAS',
          description:
              'Recordatorios silenciosos que aparecen discretamente sin molestar',
          importance: Importance.low,
          showBadge: true,
          enableVibration: false,
          enableLights: false,
          playSound: false,
        );

        // Crear los canales
        await androidPlugin.createNotificationChannel(alarmChannel);
        await androidPlugin.createNotificationChannel(notificationChannel);

        debugPrint(
            '📢 Canales de notificación configurados: ALARMAS (con sonido) y SILENCIOSAS');
      }
    } catch (e) {
      debugPrint('❌ Error al configurar canales de notificación: $e');
    }
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

      // Solo programar si la fecha es futura (con margen de 1 minuto)
      final now = DateTime.now();
      if (notificationTime.isBefore(now.subtract(Duration(minutes: 1)))) {
        debugPrint(
            '⚠️ La fecha de alarma ya pasó: $notificationTime (actual: $now)');
        return;
      }

      // 🚨 PROGRAMAR ALARMA REAL CON SONIDO DE DESPERTADOR
      final success = await RealAlarmService.scheduleRealAlarm(
        taskId: taskId,
        taskTitle: taskTitle,
        scheduledTime: notificationTime,
      );

      if (success) {
        debugPrint('🚨 ALARMA REAL programada para: $notificationTime');
        debugPrint('📝 Tarea (DESPERTADOR): $taskTitle');
        if (minutesBefore != null) {
          debugPrint(
              '⏰ Tiempo: ${minutesBefore == 0 ? "EN EL MOMENTO (DESPERTADOR)" : "$minutesBefore min antes (DESPERTADOR)"}');
        } else {
          debugPrint('⏰ Tiempo: $minutesAfter min después (DESPERTADOR)');
        }
      } else {
        debugPrint('❌ Error al programar alarma real');
      }

      // Crear el mensaje de la ALARMA DESPERTADOR
      String title = '🚨 ¡ALARMA DESPERTADOR!';
      String body;

      if (minutesBefore != null) {
        body = minutesBefore == 0
            ? '🚨 ¡TAREA AHORA!: $taskTitle'
            : '⏰ ¡ALARMA! ($minutesBefore min antes): $taskTitle';
      } else {
        body = '📢 ¡ALARMA!: $taskTitle (después de $minutesAfter min)';
      }

      // Configuración de la notificación para Android con sonido de ALARMA REAL
      final androidDetails = AndroidNotificationDetails(
        'task_alarms_loud',
        '🚨 ALARMAS DESPERTADOR',
        channelDescription:
            'Alarmas que despiertan como un despertador real para tareas importantes',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        // Usar sonido predeterminado de alarma del sistema
        // Android usará el sonido de alarma predeterminado del usuario
        // Configurar atributos de audio específicos para alarmas
        audioAttributesUsage: AudioAttributesUsage.alarm,
        // Patrón de vibración más intenso y largo (como despertador)
        vibrationPattern: Int64List.fromList(
            [0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000]),
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.alarm,
        ongoing:
            true, // PERSISTENTE - no se quita hasta que el usuario la toque
        autoCancel: false, // NO se cancela automáticamente
        fullScreenIntent: true, // Pantalla completa para despertar
        visibility:
            NotificationVisibility.public, // Visible en pantalla de bloqueo
        timeoutAfter: null, // No timeout, suena hasta que la toquen
        // Configuración adicional para que suene fuerte
        channelAction: AndroidNotificationChannelAction.createIfNotExists,
      );

      // Configuración de la notificación para iOS
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.caf', // Sonido de alarma específico para iOS
        categoryIdentifier: 'ALARM_CATEGORY',
        interruptionLevel:
            InterruptionLevel.critical, // Nivel crítico para despertar
      );

      // Configuración general
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Programar la ALARMA (ID con sufijo _alarm)
      final alarmId = '${taskId}_alarm'.hashCode.abs();

      // Crear TZDateTime de forma más segura - método actualizado
      final scheduledDate = tz.TZDateTime(
        tz.local,
        notificationTime.year,
        notificationTime.month,
        notificationTime.day,
        notificationTime.hour,
        notificationTime.minute,
        notificationTime.second,
        notificationTime.millisecond,
      );

      await _notifications.zonedSchedule(
        alarmId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        payload: 'alarm_$taskId',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint('⏰ ALARMA DESPERTADOR programada para: $notificationTime');
      debugPrint('� Tarea (DESPERTADOR): $taskTitle');
      if (minutesBefore != null) {
        debugPrint(
            '⏰ Tiempo: ${minutesBefore == 0 ? "EN EL MOMENTO (DESPERTADOR)" : "$minutesBefore min antes (DESPERTADOR)"}');
      } else {
        debugPrint('⏰ Tiempo: $minutesAfter min después (DESPERTADOR)');
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

      // Solo programar si la fecha es futura (con margen de 1 minuto)
      final now = DateTime.now();
      if (notificationTime.isBefore(now.subtract(Duration(minutes: 1)))) {
        debugPrint(
            '⚠️ La fecha de notificación ya pasó: $notificationTime (actual: $now)');
        return;
      }

      // Crear el mensaje de la NOTIFICACIÓN SILENCIOSA
      String title = '📝 Recordatorio silencioso';
      String body;

      if (minutesBefore != null) {
        body = minutesBefore == 0
            ? '📝 Tarea programada: $taskTitle'
            : '🕒 Próximamente ($minutesBefore min): $taskTitle';
      } else {
        body = '📋 Recordatorio: $taskTitle (después de $minutesAfter min)';
      }

      // Configuración de NOTIFICACIÓN para Android (COMPLETAMENTE SILENCIOSA)
      final androidDetails = AndroidNotificationDetails(
        'task_notifications_quiet',
        '📝 Recordatorios Silenciosos',
        channelDescription:
            'Recordatorios completamente silenciosos para tareas',
        importance: Importance.low, // Importancia baja
        priority: Priority.low, // Prioridad baja
        showWhen: true,
        enableVibration: false, // Sin vibración
        playSound: false, // Sin sonido
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
        ongoing: false, // No persistente
        autoCancel: true, // Se cancela fácilmente
        onlyAlertOnce: true, // Solo alerta una vez
        visibility: NotificationVisibility.private, // Menos visible
      );

      // Configuración de la notificación para iOS (silenciosa)
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
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

      // Crear TZDateTime de forma más segura - método actualizado
      final scheduledDate = tz.TZDateTime(
        tz.local,
        notificationTime.year,
        notificationTime.month,
        notificationTime.day,
        notificationTime.hour,
        notificationTime.minute,
        notificationTime.second,
        notificationTime.millisecond,
      );

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
        payload: 'notification_$taskId',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint(
          '📝 NOTIFICACIÓN SILENCIOSA programada para: $notificationTime');
      debugPrint('� Tarea (SILENCIOSO): $taskTitle');
      if (minutesBefore != null) {
        debugPrint(
            '🔕 Tiempo: ${minutesBefore == 0 ? "EN EL MOMENTO (SILENCIOSO)" : "$minutesBefore min antes (SILENCIOSO)"}');
      } else {
        debugPrint('🔕 Tiempo: $minutesAfter min después (SILENCIOSO)');
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
    try {
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          debugPrint('❌ No se pudo inicializar el servicio para la prueba');
          return;
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'test_channel',
        '🧪 Notificaciones de Prueba',
        channelDescription: 'Canal para probar notificaciones básicas',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        fullScreenIntent: false, // No es un despertador, solo una prueba
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

      debugPrint('✅ Notificación de prueba enviada');
    } catch (e) {
      debugPrint('❌ Error en notificación de prueba: $e');
    }
  }

  /// Verifica el estado del servicio de notificaciones
  static Future<bool> isServiceReady() async {
    try {
      if (!_initialized) {
        await initialize();
      }
      return _initialized;
    } catch (e) {
      debugPrint('❌ Error al verificar estado del servicio: $e');
      return false;
    }
  }
}
