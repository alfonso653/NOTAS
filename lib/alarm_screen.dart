import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
      return '⏰ ¡ALARMA!\nTu tarea comenzará en ${widget.minutes} minutos';
    } else {
      return '🔔 ¡RECORDATORIO!\nTu tarea terminó hace ${widget.minutes} minutos';
    }
  }

  Color _getBackgroundColor() {
    if (widget.alarmType == 'before') {
      return Colors.red[700]!; // Rojo fuerte para alarmas previas
    } else {
      return Colors.orange[700]!; // Naranja para recordatorios posteriores
    }
  }

  void _dismissAlarm() {
    Navigator.of(context).pop();
  }

  void _snoozeAlarm() {
    // Posponer por 5 minutos
    Navigator.of(context).pop();

    // Aquí podrías programar una nueva alarma en 5 minutos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏰ Alarma pospuesta por 5 minutos'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: SafeArea(
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
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.alarmType == 'before'
                            ? Icons.alarm
                            : Icons.notifications_active,
                        size: isSmallScreen ? 70 : 90,
                        color: _getBackgroundColor(),
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
                            fontSize: isSmallScreen ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Información de la tarea
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
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
                        foregroundColor: _getBackgroundColor(),
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
    );
  }
}
