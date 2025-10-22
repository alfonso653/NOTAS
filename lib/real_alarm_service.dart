import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'alarm_screen_service.dart';

/// Servicio para manejar alarmas REALES que suenan como despertadores
class RealAlarmService {
  static const MethodChannel _channel =
      MethodChannel('com.example.notes_module/alarm');

  /// Inicializa el servicio y configura el callback para manejar alarmas
  static Future<void> initialize() async {
    try {
      _channel.setMethodCallHandler(_handleAlarmCallback);
      debugPrint('🚨 RealAlarmService inicializado con callback');
    } catch (e) {
      debugPrint('❌ Error al inicializar RealAlarmService: $e');
    }
  }

  /// Maneja los callbacks cuando suena una alarma real
  static Future<void> _handleAlarmCallback(MethodCall call) async {
    try {
      debugPrint('🔔 Callback recibido: ${call.method}');

      if (call.method == 'onAlarmTriggered') {
        final String taskId = call.arguments['taskId'] ?? '';
        final String taskTitle = call.arguments['taskTitle'] ?? 'Alarma';
        final int scheduledTimeMs = call.arguments['scheduledTime'] ?? 0;

        final DateTime scheduledTime =
            DateTime.fromMillisecondsSinceEpoch(scheduledTimeMs);

        debugPrint('🚨 ALARMA REAL ACTIVADA: $taskTitle (ID: $taskId)');
        debugPrint('⏰ Tiempo programado: $scheduledTime');

        // Mostrar pantalla completa de alarma automáticamente
        await AlarmScreenService.showFullScreenAlarm(
          taskTitle: taskTitle,
          taskDescription: 'Alarma programada - ¡Es hora de realizar tu tarea!',
          taskDateTime: scheduledTime,
          alarmType: 'before',
          minutes: 0,
        );

        debugPrint('🖥️ Pantalla completa de alarma mostrada para: $taskTitle');
      }
    } catch (e) {
      debugPrint('❌ Error al manejar callback de alarma: $e');
    }
  }

  /// Programa una alarma REAL que sonará como un despertador
  static Future<bool> scheduleRealAlarm({
    required String taskId,
    required String taskTitle,
    required DateTime scheduledTime,
  }) async {
    try {
      final success = await _channel.invokeMethod('scheduleAlarm', {
        'taskId': taskId,
        'taskTitle': taskTitle,
        'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      });

      debugPrint('🚨 ALARMA REAL programada: $success');
      debugPrint('📝 Tarea: $taskTitle');
      debugPrint('⏰ Hora: $scheduledTime');

      return success ?? false;
    } catch (e) {
      debugPrint('❌ Error al programar alarma real: $e');
      return false;
    }
  }

  /// Cancela una alarma REAL
  static Future<bool> cancelRealAlarm(String taskId) async {
    try {
      final success = await _channel.invokeMethod('cancelAlarm', {
        'taskId': taskId,
      });

      debugPrint('🗑️ ALARMA REAL cancelada: $success');
      return success ?? false;
    } catch (e) {
      debugPrint('❌ Error al cancelar alarma real: $e');
      return false;
    }
  }

  /// Detiene el SONIDO de la alarma que está sonando actualmente
  /// Mantiene la notificación visual como recordatorio para el usuario
  static Future<bool> stopCurrentAlarm() async {
    try {
      final success = await _channel.invokeMethod('stopAlarm');
      debugPrint(
          '🛑 Sonido de alarma detenido (notificación mantenida): $success');
      return success ?? false;
    } catch (e) {
      debugPrint('❌ Error al detener sonido de alarma: $e');
      return false;
    }
  }
}
