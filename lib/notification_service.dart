import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'real_alarm_service.dart';
import 'alarm_screen_service.dart';

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

  /// Solicita permisos de notificación solo cuando se necesiten
  static Future<bool> requestPermissionsIfNeeded() async {
    try {
      bool allPermissionsGranted = true;

      // Permisos para Android 13+
      try {
        if (await Permission.notification.isDenied) {
          final result = await Permission.notification.request();
          debugPrint('📱 Permiso de notificaciones solicitado: $result');
          if (result != PermissionStatus.granted) {
            allPermissionsGranted = false;
          }
        } else {
          debugPrint('✅ Permisos de notificación ya concedidos');
        }
      } catch (e) {
        debugPrint('⚠️ Error al verificar permisos de notificación: $e');
        allPermissionsGranted = false;
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

          if (notificationPermission != true || alarmPermission != true) {
            allPermissionsGranted = false;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error al solicitar permisos específicos de Android: $e');
        allPermissionsGranted = false;
      }

      return allPermissionsGranted;
    } catch (e) {
      debugPrint('❌ Error general al solicitar permisos: $e');
      return false;
    }
  }

  /// Maneja cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      debugPrint('🔔 Notificación tocada: ${response.payload}');

      if (response.payload != null && response.payload!.startsWith('alarm_')) {
        // Es una alarma - mostrar pantalla completa
        _showFullScreenAlarmFromPayload(response.payload!);
      } else if (response.payload != null &&
          response.payload!.startsWith('notification_')) {
        // Es una notificación normal - mostrar pantalla completa también
        _showFullScreenAlarmFromPayload(response.payload!);
      }
    } catch (e) {
      debugPrint('❌ Error al manejar notificación tocada: $e');
    }
  }

  /// Muestra la pantalla de alarma completa basada en el payload
  static void _showFullScreenAlarmFromPayload(String payload) {
    try {
      // Extraer información del payload
      // Formato esperado: "alarm_taskId" o "notification_taskId"
      final isAlarm = payload.startsWith('alarm_');
      final taskId =
          payload.replaceFirst(isAlarm ? 'alarm_' : 'notification_', '');

      // Mostrar pantalla completa cuando se toca la notificación
      AlarmScreenService.showFullScreenAlarm(
        taskTitle: 'Tarea Programada',
        taskDescription: isAlarm
            ? 'Alarma activada - Toque para ver detalles'
            : 'Notificación de tarea - Toque para ver detalles',
        taskDateTime: DateTime.now(),
        alarmType: isAlarm ? 'before' : 'after',
        minutes: 5,
      );

      debugPrint('🚨 Mostrando pantalla de alarma completa para: $taskId');
      debugPrint('📱 Tipo: ${isAlarm ? "ALARMA" : "NOTIFICACIÓN"}');
    } catch (e) {
      debugPrint('❌ Error al mostrar pantalla de alarma desde payload: $e');
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

        // 🔊 Canal para NOTIFICACIONES (¡SÚPER SONORAS!)
        final AndroidNotificationChannel notificationChannel =
            AndroidNotificationChannel(
          'task_notifications_silent',
          '🔊 NOTIFICACIONES SÚPER SONORAS',
          description:
              'Recordatorios MUY SONOROS que suenan fuerte para asegurar que se escuchen',
          importance: Importance.max, // ¡IMPORTANCIA MÁXIMA!
          showBadge: true, // Con badge bien visible
          enableVibration: true, // ¡CON VIBRACIÓN!
          enableLights: true, // ¡CON LUCES!
          playSound: true, // ¡CON SONIDO!
          sound: const RawResourceAndroidNotificationSound(
              'notification'), // Sonido específico
          vibrationPattern: Int64List.fromList(
              [0, 1000, 500, 1000, 500, 1000]), // Vibración MÁS intensa
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

  /// Muestra inmediatamente la pantalla de alarma completa
  static Future<void> showImmediateAlarm({
    required String taskTitle,
    required String taskDescription,
    required DateTime taskDateTime,
    required String alarmType, // 'before' o 'after'
    required int minutes,
  }) async {
    try {
      debugPrint('🚨 Mostrando alarma completa inmediata para: $taskTitle');

      await AlarmScreenService.showFullScreenAlarm(
        taskTitle: taskTitle,
        taskDescription: taskDescription,
        taskDateTime: taskDateTime,
        alarmType: alarmType,
        minutes: minutes,
      );
    } catch (e) {
      debugPrint('❌ Error al mostrar alarma inmediata: $e');
    }
  }

  /// Programa una ALARMA (sonido fuerte) para una tarea
  static Future<bool> scheduleTaskAlarm({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    String? taskDescription,
    int? minutesBefore,
    int? minutesAfter,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Solicitar permisos solo cuando se necesiten
    final hasPermissions = await requestPermissionsIfNeeded();
    if (!hasPermissions) {
      debugPrint(
          '❌ No se pudieron obtener los permisos necesarios para la alarma');
      return false;
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
        debugPrint('⚠️ No hay tiempo configurado para la alarma');
        return false; // No hay tiempo configurado
      }

      // Solo programar si la fecha es futura (con margen de 1 minuto)
      final now = DateTime.now();
      if (notificationTime.isBefore(now.subtract(Duration(minutes: 1)))) {
        debugPrint(
            '⚠️ La fecha de alarma ya pasó: $notificationTime (actual: $now)');
        return false;
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
      return true;
    } catch (e) {
      debugPrint('❌ Error al programar alarma: $e');
      return false;
    }
  }

  /// Programa una NOTIFICACIÓN (silenciosa) para una tarea
  static Future<bool> scheduleTaskNotification({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    int? minutesBefore,
    int? minutesAfter,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Solicitar permisos solo cuando se necesiten
    final hasPermissions = await requestPermissionsIfNeeded();
    if (!hasPermissions) {
      debugPrint(
          '❌ No se pudieron obtener los permisos necesarios para la notificación');
      return false;
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
        debugPrint('⚠️ No hay tiempo configurado para la notificación');
        return false; // No hay tiempo configurado
      }

      // Solo programar si la fecha es futura (con margen de 1 minuto)
      final now = DateTime.now();
      if (notificationTime.isBefore(now.subtract(Duration(minutes: 1)))) {
        debugPrint(
            '⚠️ La fecha de notificación ya pasó: $notificationTime (actual: $now)');
        return false;
      }

      // Crear el mensaje de la NOTIFICACIÓN ¡SÚPER SONORA!
      String title = '� ¡RECORDATORIO SÚPER SONORO!';
      String body;

      if (minutesBefore != null) {
        body = minutesBefore == 0
            ? '� ¡TAREA PROGRAMADA AHORA: $taskTitle!'
            : '⏰ ¡PRÓXIMAMENTE ($minutesBefore min): $taskTitle!';
      } else {
        body =
            '� ¡RECORDATORIO IMPORTANTE: $taskTitle! (después de $minutesAfter min)';
      }

      // Configuración de NOTIFICACIÓN para Android (¡SÚPER SONORA PERO DETECTABLE!)
      final androidDetails = AndroidNotificationDetails(
        'task_notifications_silent', // Usar el canal correcto que ya está configurado
        '📝 Recordatorios Súper Sonoros',
        channelDescription:
            'Recordatorios MUY SONOROS que suenan fuerte para no perderse',
        importance: Importance.max, // ¡IMPORTANCIA MÁXIMA!
        priority: Priority.max, // ¡PRIORIDAD MÁXIMA!
        showWhen: true,
        enableVibration: true, // ¡CON VIBRACIÓN FUERTE!
        playSound: true, // ¡CON SONIDO FUERTE!
        sound: const RawResourceAndroidNotificationSound(
            'notification'), // Sonido específico de sistema
        vibrationPattern: Int64List.fromList(
            [0, 1000, 500, 1000, 500, 1000]), // Vibración MÁS intensa
        icon: '@mipmap/ic_launcher',
        category:
            AndroidNotificationCategory.alarm, // Como alarma para que suene más
        ongoing: false, // NO persistente para que se pueda quitar
        autoCancel: true, // SÍ se cancela al tocar
        onlyAlertOnce: false, // Alerta SIEMPRE (esto es clave para que suene)
        visibility: NotificationVisibility.public, // MUY VISIBLE
        silent: false, // ¡NADA DE SILENCIO!
        fullScreenIntent:
            false, // Sin pantalla completa para no ser muy invasivo
        enableLights: true, // Luces LED activadas
        ticker: title, // Texto que aparece en la barra de estado
        when: DateTime.now().millisecondsSinceEpoch, // Marca de tiempo actual
        actions: [
          AndroidNotificationAction(
            'STOP_ALARM',
            '🛑 DETENER',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ], // Botón para detener
      );

      // Configuración de la notificación para iOS (¡SÚPER SONORA!)
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true, // ¡CON SONIDO FUERTE!
        sound: 'default', // Sonido predeterminado
        interruptionLevel: InterruptionLevel.critical, // Nivel crítico
        categoryIdentifier: 'ALARM_CATEGORY', // Categoría de alarma
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
          '� ¡NOTIFICACIÓN SÚPER SONORA programada para: $notificationTime!');
      debugPrint('🚨 Tarea (¡SÚPER SONORO!): $taskTitle');
      if (minutesBefore != null) {
        debugPrint(
            '� Tiempo: ${minutesBefore == 0 ? "EN EL MOMENTO (¡SÚPER SONORO!)" : "$minutesBefore min antes (¡SÚPER SONORO!)"}');
      } else {
        debugPrint('� Tiempo: $minutesAfter min después (¡SÚPER SONORO!)');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error al programar notificación: $e');
      return false;
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

  /// Muestra inmediatamente una alarma de pantalla completa (para testing y alarmas inmediatas)
  static Future<void> showImmediateAlarmForTesting({
    required String taskTitle,
    required String taskDescription,
    required DateTime taskDateTime,
    required String alarmType,
    required int minutes,
  }) async {
    try {
      debugPrint('🚨 Activando alarma inmediata de pantalla completa');
      debugPrint('📝 Tarea: $taskTitle');

      await AlarmScreenService.showFullScreenAlarm(
        taskTitle: taskTitle,
        taskDescription: taskDescription,
        taskDateTime: taskDateTime,
        alarmType: alarmType,
        minutes: minutes,
      );

      debugPrint('🖥️ Pantalla de alarma activada correctamente');
    } catch (e) {
      debugPrint('❌ Error al mostrar alarma inmediata: $e');
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
