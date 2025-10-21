import 'package:flutter/material.dart';
import 'alarm_screen.dart';

/// Servicio global para gestionar las pantallas de alarma completa
class AlarmScreenService {
  static final AlarmScreenService _instance = AlarmScreenService._internal();
  factory AlarmScreenService() => _instance;
  AlarmScreenService._internal();

  // Contexto global para poder navegar
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Muestra la pantalla de alarma completa
  static Future<void> showFullScreenAlarm({
    required String taskTitle,
    required String taskDescription,
    required DateTime taskDateTime,
    required String alarmType, // 'before' o 'after'
    required int minutes,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ No se puede mostrar pantalla de alarma: contexto nulo');
      return;
    }

    try {
      // Verificar si ya hay una pantalla de alarma abierta
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == '/alarm') {
        debugPrint('⚠️ Ya hay una pantalla de alarma abierta');
        return;
      }

      debugPrint('🚨 Mostrando pantalla de alarma completa para: $taskTitle');

      // Mostrar la pantalla de alarma como modal completo
      await Navigator.of(context).push(
        PageRouteBuilder(
          settings: const RouteSettings(name: '/alarm'),
          pageBuilder: (context, animation, secondaryAnimation) {
            return AlarmScreen(
              taskTitle: taskTitle,
              taskDescription: taskDescription,
              taskDateTime: taskDateTime,
              alarmType: alarmType,
              minutes: minutes,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Animación de fade in rápida
            return FadeTransition(
              opacity: Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          barrierDismissible: false, // No se puede cerrar tocando afuera
          fullscreenDialog: true, // Pantalla completa
        ),
      );

      debugPrint('✅ Pantalla de alarma cerrada');
    } catch (e) {
      debugPrint('❌ Error al mostrar pantalla de alarma: $e');
    }
  }

  /// Cierra la pantalla de alarma si está abierta
  static void dismissAlarm() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/alarm') {
      Navigator.of(context).pop();
      debugPrint('🔕 Pantalla de alarma cerrada manualmente');
    }
  }

  /// Verifica si hay una pantalla de alarma abierta
  static bool get isAlarmScreenOpen {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    final currentRoute = ModalRoute.of(context)?.settings.name;
    return currentRoute == '/alarm';
  }
}
