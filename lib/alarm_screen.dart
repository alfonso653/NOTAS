import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'real_alarm_service.dart';

/// Pantalla de alarma que ocupa toda la pantalla
class AlarmScreen extends StatefulWidget {
  final String taskTitle;
  final String taskDescription;
  final DateTime taskDateTime;
  final String alarmType; // 'before' o 'after'
  final int minutes; // minutos antes o después

  const AlarmScreen({
    super.key,
    required this.taskTitle,
    required this.taskDescription,
    required this.taskDateTime,
    required this.alarmType,
    required this.minutes,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Hacer que la pantalla se mantenga encendida
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Animación de pulso para el ícono de alarma
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Animación de vibración para el texto
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Iniciar vibración del texto
    _startShaking();
  }

  void _startShaking() {
    _shakeController.repeat(reverse: true);

    // Parar la vibración después de 10 segundos
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _shakeController.stop();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    // Restaurar el modo normal de la pantalla
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _getAlarmMessage() {
    if (widget.alarmType == 'before') {
      return '⏰ Es hora!\nTu tarea comenzará en ${widget.minutes} minutos';
    } else {
      return '🌟 Recordatorio\nTu tarea terminó hace ${widget.minutes} minutos';
    }
  }

  LinearGradient _getBackgroundGradient() {
    if (widget.alarmType == 'before') {
      // Gradiente azul-púrpura elegante para alarmas previas
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF667eea), // Azul suave
          Color(0xFF764ba2), // Púrpura elegante
        ],
      );
    } else {
      // Gradiente verde-teal para recordatorios posteriores
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF11998e), // Teal profundo
          Color(0xFF38ef7d), // Verde fresco
        ],
      );
    }
  }

  Color _getAccentColor() {
    if (widget.alarmType == 'before') {
      return const Color(0xFF667eea);
    } else {
      return const Color(0xFF11998e);
    }
  }

  void _dismissAlarm() async {
    try {
      // Detener solo el SONIDO de la alarma nativa (mantener notificación visual)
      await RealAlarmService.stopCurrentAlarm();
      debugPrint('🛑 Sonido de alarma detenido - notificación mantenida como recordatorio');
    } catch (e) {
      debugPrint('❌ Error al detener sonido de alarma: $e');
    }
    
    // Cerrar la pantalla
    Navigator.of(context).pop();
  }

  void _snoozeAlarm() async {
    try {
      // Detener solo el SONIDO de la alarma actual (mantener notificación)
      await RealAlarmService.stopCurrentAlarm();
      debugPrint('🛑 Sonido de alarma detenido para posponer - notificación mantenida');
      
      // Programar nueva alarma en 5 minutos
      final newAlarmTime = DateTime.now().add(const Duration(minutes: 5));
      await RealAlarmService.scheduleRealAlarm(
        taskId: 'snooze_${DateTime.now().millisecondsSinceEpoch}',
        taskTitle: '⏰ ${widget.taskTitle} (Pospuesta)',
        scheduledTime: newAlarmTime,
      );
      
      debugPrint('⏰ Nueva alarma programada para: $newAlarmTime');
    } catch (e) {
      debugPrint('❌ Error al posponer alarma: $e');
    }
    
    // Cerrar pantalla
    Navigator.of(context).pop();

    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏰ Alarma pospuesta por 5 minutos - Notificación mantenida como recordatorio'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: _getBackgroundGradient(),
        ),
        child: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Ícono de alarma animado
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: isSmallScreen ? 120 : 150,
                      height: isSmallScreen ? 120 : 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 25,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: _getAccentColor().withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.alarmType == 'before'
                            ? Icons.access_time_rounded
                            : Icons.check_circle_outline_rounded,
                        size: isSmallScreen ? 70 : 90,
                        color: _getAccentColor(),
                      ),
                    ),
                  );
                },
              ),

              // Mensaje principal animado
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: Column(
                      children: [
                        Text(
                          _getAlarmMessage(),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 28 : 36,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Información de la tarea
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.taskTitle,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Georgia',
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              if (widget.taskDescription.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  widget.taskDescription,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    color: Colors.white.withOpacity(0.9),
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Hora de la tarea
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  DateFormat('HH:mm - dd/MM/yyyy')
                                      .format(widget.taskDateTime),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Botones de acción
              Column(
                children: [
                  // Botón principal - Detener
                  SizedBox(
                    width: double.infinity,
                    height: isSmallScreen ? 65 : 75,
                    child: ElevatedButton(
                      onPressed: _dismissAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _getAccentColor(),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ).copyWith(
                        overlayColor: MaterialStateProperty.all(
                          _getAccentColor().withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        widget.alarmType == 'before'
                            ? '✅ ENTENDIDO'
                            : '✅ COMPLETADO',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botón secundario - Posponer (solo para alarmas previas)
                  if (widget.alarmType == 'before')
                    SizedBox(
                      width: double.infinity,
                      height: isSmallScreen ? 55 : 65,
                      child: OutlinedButton(
                        onPressed: _snoozeAlarm,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          '⏰ POSPONER 5 MIN',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
