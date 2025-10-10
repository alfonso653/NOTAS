import 'package:flutter/material.dart';
import 'dart:async';
import 'calendar_verse_service.dart';

class DailyVerseWidget extends StatefulWidget {
  final DateTime selectedDate;
  
  const DailyVerseWidget({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<DailyVerseWidget> createState() => _DailyVerseWidgetState();
}

class _DailyVerseWidgetState extends State<DailyVerseWidget> with TickerProviderStateMixin {
  Map<String, dynamic>? _verseData;
  bool _isLoading = true;
  bool _showingVerse = true; // true = versículo, false = frase
  bool _isBlinking = false;
  Timer? _contentTimer;
  Timer? _blinkTimer;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    
    // Configurar animación de difuminado suave
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800), // Más lento y suave
      vsync: this,
    );
    
    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut, // Curva suave
    ));
    
    _loadVerse();
  }

  @override
  void didUpdateWidget(DailyVerseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      print('📅 Fecha cambió - Cargando nuevo versículo');
      _loadVerse();
    }
  }

  @override
  void dispose() {
    _contentTimer?.cancel();
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _loadVerse() async {
    setState(() {
      _isLoading = true;
    });

    final verseData = await CalendarVerseService.getVerseForDate(widget.selectedDate);
    
    if (mounted) {
      setState(() {
        _verseData = verseData;
        _isLoading = false;
        _showingVerse = true; // Empezar mostrando el versículo
      });
      
      // Iniciar el ciclo de animación si hay datos
      if (_verseData != null) {
        _startAnimationCycle();
      }
    }
  }

  void _startAnimationCycle() {
    // Cancelar timers existentes
    _contentTimer?.cancel();
    _blinkTimer?.cancel();
    
    print('🔄 Iniciando ciclo de animación - Mostrando: ${_showingVerse ? 'VERSÍCULO' : 'FRASE'}');
    
    // Mostrar contenido por 10 segundos, luego parpadear y cambiar
    _contentTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        print('⏰ 10 segundos completados - Cambiando de ${_showingVerse ? 'VERSÍCULO' : 'FRASE'} a ${_showingVerse ? 'FRASE' : 'VERSÍCULO'}');
        _startBlinkAndSwitch();
      } else {
        timer.cancel();
      }
    });
  }

  void _startBlinkAndSwitch() {
    setState(() {
      _isBlinking = true;
    });
    
    print('✨ Iniciando difuminado...');
    
    // Iniciar animación de difuminado (fade out -> cambio -> fade in)
    _blinkController.forward().then((_) {
      // Cambiar contenido en el punto más transparente
      if (mounted) {
        setState(() {
          _showingVerse = !_showingVerse;
        });
        print('🔄 Contenido cambiado a: ${_showingVerse ? 'VERSÍCULO' : 'FRASE'}');
        // Fade in con el nuevo contenido
        _blinkController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isBlinking = false;
            });
            print('✅ Difuminado completado - Nuevo ciclo de 10 segundos');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B73FF)),
          ),
        ),
      );
    }

    if (_verseData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No hay versículo disponible para esta fecha',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: _isBlinking ? _blinkAnimation.value : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: double.infinity,
            height: double.infinity, // Asegurar que use todo el espacio disponible
            padding: const EdgeInsets.all(12.0),
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  const Color(0xFFFEF7F0).withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B73FF).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF6B73FF).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600), // Transición más suave
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _showingVerse ? _buildVerseContent() : _buildQuoteContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseContent() {
    return Column(
      key: const ValueKey('verse'),
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Indicador de contenido
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book,
              size: 14,
              color: const Color(0xFF6B73FF).withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Versículo del día',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B73FF).withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        // Versículo principal - Completamente responsive
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '"${_verseData!['verse']}"',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: null, // Permitir múltiples líneas con scroll
                ),
              ),
            ),
          ),
        ),
        
        // Referencia bíblica - Texto responsive
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF6B73FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            _verseData!['reference'] ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B73FF),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteContent() {
    // Solo mostrar si hay cita disponible
    if (_verseData!['quote'] == null || _verseData!['quote'].toString().isEmpty) {
      return _buildVerseContent(); // Volver al versículo si no hay cita
    }

    return Column(
      key: const ValueKey('quote'),
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Indicador de contenido
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_quote,
              size: 14,
              color: Colors.amber.shade700.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Reflexión',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.amber.shade700.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        // Cita inspiracional - Completamente responsive
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '"${_verseData!['quote']}"',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade800,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: null, // Permitir múltiples líneas con scroll
                ),
              ),
            ),
          ),
        ),
        
        // Autor - Texto responsive
        if (_verseData!['author'] != null && _verseData!['author'].toString().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.amber.shade200,
                width: 1,
              ),
            ),
            child: Text(
              '— ${_verseData!['author']}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.amber.shade700,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}