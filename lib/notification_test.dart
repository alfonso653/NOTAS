import 'package:flutter/material.dart';
import 'notification_service.dart';

/// Widget simple para probar las notificaciones
class NotificationTestWidget extends StatelessWidget {
  const NotificationTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⏰ Despertador vs 🔕 Silencioso'),
        backgroundColor: const Color(0xFF374151),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '⏰ Alarmas vs 🔕 Notificaciones',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await NotificationService.showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Notificación de prueba enviada'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF374151),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Probar Notificación Inmediata'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Programar una ALARMA DESPERTADOR en 10 segundos
                  final testTime =
                      DateTime.now().add(const Duration(seconds: 10));

                  await NotificationService.scheduleTaskAlarm(
                    taskId: 'test_alarm_despertador',
                    taskTitle: 'DESPERTADOR DE PRUEBA',
                    taskDateTime: testTime,
                    minutesBefore: 0,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '⏰ DESPERTADOR programado para 10 segundos - ¡VA A SONAR FUERTE!'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al programar despertador: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('⏰ Probar DESPERTADOR en 10 segundos'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Programar una NOTIFICACIÓN SILENCIOSA en 5 segundos
                  final testTime =
                      DateTime.now().add(const Duration(seconds: 5));

                  await NotificationService.scheduleTaskNotification(
                    taskId: 'test_notification_silent',
                    taskTitle: 'Recordatorio Silencioso',
                    taskDateTime: testTime,
                    minutesBefore: 0,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '🔕 Notificación silenciosa programada para 5 segundos'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al programar notificación: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child:
                  const Text('🔕 Probar Notificación SILENCIOSA en 5 segundos'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final isReady = await NotificationService.isServiceReady();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isReady
                            ? '✅ Servicio de notificaciones listo'
                            : '❌ Servicio de notificaciones no disponible'),
                        backgroundColor: isReady ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al verificar servicio: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Verificar Estado del Servicio'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Diferencias importantes:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '⏰ ALARMA (Despertador): Sonido FUERTE, vibración intensa, pantalla completa, NO se cancela sola\n\n'
              '🔕 NOTIFICACIÓN (Silenciosa): Sin sonido, sin vibración, discreta, se cancela fácilmente\n\n'
              '1. "Probar Notificación Inmediata" = prueba básica\n'
              '2. "Probar DESPERTADOR" = ¡VA A SONAR FUERTE como despertador!\n'
              '3. "Probar Notificación SILENCIOSA" = completamente silenciosa\n\n'
              '⚠️ La ALARMA está diseñada para DESPERTAR al usuario',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
