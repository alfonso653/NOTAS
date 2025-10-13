import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Servicio para manejar alarmas REALES que suenan como despertadores
class RealAlarmService {
  static const MethodChannel _channel =
      MethodChannel('com.example.notes_module/alarm');

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

  /// Detiene la alarma que está sonando actualmente
  static Future<bool> stopCurrentAlarm() async {
    try {
      final success = await _channel.invokeMethod('stopAlarm');
      debugPrint('🛑 Alarma detenida: $success');
      return success ?? false;
    } catch (e) {
      debugPrint('❌ Error al detener alarma: $e');
      return false;
    }
  }
}
