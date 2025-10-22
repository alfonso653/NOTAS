import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// FUNCIÓN DE NOTIFICACIÓN QUE SÍ FUNCIONA
class NotificationFix {
  static Future<bool> scheduleTaskNotification({
    required String taskId,
    required String taskTitle,
    required DateTime taskDateTime,
    int? minutesBefore,
    int? minutesAfter,
  }) async {
    debugPrint('🔍 =================================');
    debugPrint('🔍 PROGRAMANDO NOTIFICACIÓN CON MÉTODO QUE FUNCIONA');
    debugPrint('🔍 TaskTitle: $taskTitle');
    debugPrint('🔍 TaskDateTime: $taskDateTime');
    debugPrint('🔍 MinutesBefore: $minutesBefore');
    debugPrint('🔍 MinutesAfter: $minutesAfter');

    // Calcular el tiempo exacto de la notificación
    DateTime notificationTime;
    if (minutesBefore != null) {
      notificationTime = minutesBefore == 0
          ? taskDateTime  // Exactamente a la hora de la tarea
          : taskDateTime.subtract(Duration(minutes: minutesBefore));
    } else if (minutesAfter != null) {
      notificationTime = taskDateTime.add(Duration(minutes: minutesAfter));
    } else {
      debugPrint('⚠️ ERROR: No hay tiempo configurado');
      return false;
    }

    final now = DateTime.now();
    final diff = notificationTime.difference(now);
    
    debugPrint('🔍 NotificationTime: $notificationTime');
    debugPrint('🔍 Tiempo hasta notificación: ${diff.inMinutes} min ${diff.inSeconds % 60} seg');

    if (diff.isNegative || diff.inSeconds < 5) {
      debugPrint('⚠️ RECHAZADO: Tiempo muy pequeño');
      return false;
    }

    // PROGRAMAR CON Future.delayed (método más simple que funciona)
    Future.delayed(diff, () async {
      debugPrint('🔔 ⏰ EJECUTANDO NOTIFICACIÓN: $taskTitle');
      await NotificationService.showNotificationBar(
        title: '🔔 EMETH AGENDA - Recordatorio',
        body: 'Recordatorio: $taskTitle',
      );
    });

    debugPrint('🎉 ¡NOTIFICACIÓN PROGRAMADA EXITOSAMENTE!');
    debugPrint('🔍 =================================');
    return true;
  }
}