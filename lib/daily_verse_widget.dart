import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'calendar_verse_service.dart';
import 'quotes_service.dart';

class DailyVerseWidget extends StatefulWidget {
  final DateTime selectedDate;

  const DailyVerseWidget({
    Key? key,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<DailyVerseWidget> createState() => _DailyVerseWidgetState();
}

class _DailyVerseWidgetState extends State<DailyVerseWidget>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _verseData;
  Map<String, dynamic>? _quoteData;
  bool _isLoading = true;
  bool _showingVerse = true; // true = versículo, false = cita
  bool _isBlinking = false;
  Timer? _contentTimer;
  Timer? _blinkTimer;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar animación de difuminado optimizada
    _blinkController = AnimationController(
      duration:
          const Duration(milliseconds: 400), // Reducido para mejor rendimiento
      vsync: this,
    );

    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));

    _loadContent();
  }

  @override
  void dispose() {
    _contentTimer?.cancel();
    _blinkTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  String _convertToChapterUrl(String originalUrl, String reference) {
    // Convertir URL de versículo específico a capítulo completo

    // Extraer el libro y capítulo de la referencia
    // Ejemplos: "1 Tesalonicenses 5:18" -> "1 Tesalonicenses 5"
    //          "Salmo 100:4" -> "Salmo 100"
    //          "Filipenses 4:6" -> "Filipenses 4"

    String chapterReference = reference;
    if (reference.contains(':')) {
      // Remover el versículo específico, mantener solo libro y capítulo
      chapterReference = reference.split(':')[0];
    }

    print('📑 Capítulo a buscar: $chapterReference');

    // Convertir diferentes tipos de URLs a capítulo completo
    if (originalUrl.contains('biblegateway.com')) {
      // Para BibleGateway: cambiar el passage para mostrar el capítulo completo
      String encodedChapter = Uri.encodeComponent(chapterReference);
      String newUrl =
          'https://www.biblegateway.com/passage/?search=$encodedChapter&version=RVR1960';
      print('✅ URL convertida (BibleGateway): $newUrl');
      return newUrl;
    } else if (originalUrl.contains('bible.com')) {
      // Para Bible.com: construir URL de capítulo
      // Necesitaríamos mapear libros a abreviaciones, por ahora mantenemos original
      print('ℹ️ Bible.com detectado, manteniendo URL original por ahora');
      return originalUrl;
    } else if (originalUrl.contains('dailyverses.net')) {
      // Para DailyVerses: cambiar a BibleGateway para mejor experiencia de capítulo
      String encodedChapter = Uri.encodeComponent(chapterReference);
      String newUrl =
          'https://www.biblegateway.com/passage/?search=$encodedChapter&version=RVR1960';
      print('✅ URL convertida (DailyVerses->BibleGateway): $newUrl');
      return newUrl;
    }

    // Si no reconocemos el dominio, crear URL genérica en BibleGateway
    String encodedChapter = Uri.encodeComponent(chapterReference);
    String newUrl =
        'https://www.biblegateway.com/passage/?search=$encodedChapter&version=RVR1960';
    print('✅ URL genérica creada: $newUrl');
    return newUrl;
  }

  Future<void> _openSource(List<dynamic>? sources) async {
    print('🔗 Botón de fuente tocado!');
    print('📄 Sources recibidas: $sources');

    if (sources != null && sources.isNotEmpty) {
      final String url = sources.first.toString();
      print('🌐 URL a abrir: $url');

      try {
        final Uri uri = Uri.parse(url);
        print('✅ URI parseada correctamente: $uri');

        // Estrategia 1: Abrir en aplicación externa (navegador independiente)
        print('🚀 Intentando abrir en aplicación externa...');
        try {
          bool launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          print('✅ Abierto en aplicación externa: $launched');
          return; // Si funciona, salimos aquí
        } catch (e1) {
          print('❌ Falló aplicación externa: $e1');
        }

        // Estrategia 2: Modo por defecto del sistema
        print('🔄 Intentando modo platformDefault...');
        try {
          bool launched = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          print('✅ Resultado con platformDefault: $launched');
          return; // Si funciona, salimos aquí
        } catch (e2) {
          print('❌ También falló platformDefault: $e2');
        }

        // Estrategia 3: Como último recurso, dentro de la app
        print('🔄 Como último recurso, intentando dentro de la app...');
        try {
          bool launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
          print('✅ Abierto dentro de la app: $launched');
        } catch (e3) {
          print('❌ Todas las estrategias fallaron: $e3');
        }
      } catch (e) {
        print('❌ Error al parsear/abrir la URL: $e');
      }
    } else {
      print('⚠️ No hay sources disponibles para este contenido');
    }
  }

  @override
  void didUpdateWidget(DailyVerseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      // Fecha cambió - Cargando nuevo contenido
      _loadContent();
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
    });

    // Cargar versículo y cita en paralelo
    final results = await Future.wait([
      CalendarVerseService.getVerseForDate(widget.selectedDate),
      QuotesService.getQuoteForDate(widget.selectedDate),
    ]);

    if (mounted) {
      setState(() {
        _verseData = results[0];
        _quoteData = results[1];
        _isLoading = false;
        _showingVerse = true; // Empezar mostrando el versículo
      });

      // Iniciar el ciclo de animación si hay datos
      if ((_verseData != null || _quoteData != null)) {
        _startAnimationCycle();
      }
    }
  }

  void _startAnimationCycle() {
    // Cancelar timers existentes
    _contentTimer?.cancel();
    _blinkTimer?.cancel();

    print(
        '🔄 Iniciando ciclo de animación - Mostrando: ${_showingVerse ? 'VERSÍCULO' : 'CITA'}');

    // Mostrar contenido por 10 segundos, luego parpadear y cambiar
    _contentTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        print(
            '⏰ Han pasado 10 segundos - Iniciando difuminado para cambiar de ${_showingVerse ? 'VERSÍCULO' : 'CITA'} a ${!_showingVerse ? 'VERSÍCULO' : 'CITA'}');
        _performBlinkTransition();
      }
    });
  }

  void _performBlinkTransition() {
    if (!mounted) return;

    setState(() {
      _isBlinking = true;
    });

    print('🌀 Iniciando difuminado...');

    // Fade out
    _blinkController.forward().then((_) {
      // Cambiar contenido en el punto más transparente
      if (mounted) {
        setState(() {
          _showingVerse = !_showingVerse;
        });
        print(
            '🔄 Contenido cambiado a: ${_showingVerse ? 'VERSÍCULO' : 'CITA'}');
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isCompactMode = keyboardHeight > 100;

    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_verseData == null && _quoteData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No hay contenido disponible para esta fecha',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.all(isCompactMode ? 8.0 : 12.0),
            margin: EdgeInsets.all(isCompactMode ? 4.0 : 8.0),
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
                  color: const Color(0xFF374151).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF374151).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
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
              child: _showingVerse
                  ? _buildVerseContent(isCompactMode)
                  : _buildQuoteContent(isCompactMode),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseContent(bool isCompactMode) {
    return Stack(
      children: [
        Column(
          key: const ValueKey('verse'),
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Indicador de versículo
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book,
                  size: isCompactMode ? 12 : 14,
                  color: const Color(0xFF374151).withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Versículo del día',
                  style: TextStyle(
                    fontSize: isCompactMode ? 9 : 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151).withOpacity(0.7),
                  ),
                ),
              ],
            ),

            // Texto del versículo - CLICKEABLE
            Expanded(
              flex: 3,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isCompactMode ? 4.0 : 8.0),
                  child: GestureDetector(
                    onTap: () => _showFullScreenText(
                      context,
                      '"${_verseData!['verse']}"',
                      _verseData!['reference'] ?? '',
                      true, // isVerse = true
                    ),
                    child: Text(
                      '"${_verseData!['verse']}"',
                      style: TextStyle(
                        fontSize: isCompactMode ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: isCompactMode ? 1.2 : 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isCompactMode ? 3 : null,
                      overflow: isCompactMode ? TextOverflow.ellipsis : null,
                    ),
                  ),
                ),
              ),
            ),

            // Referencia bíblica
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isCompactMode ? 8 : 10,
                  vertical: isCompactMode ? 2 : 3),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isCompactMode ? 12 : 15),
              ),
              child: Text(
                _verseData!['reference'] ?? '',
                style: TextStyle(
                  fontSize: isCompactMode ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        // Botón de fuente para versículos
        Positioned(
          bottom: 8,
          left: 8,
          child: GestureDetector(
            onTap: () {
              // Para versículos, convertir a URL del capítulo completo
              final cita = _verseData?['cita'];
              final reference = _verseData?['reference'];

              if (cita != null && reference != null) {
                // Convertir la URL del versículo específico al capítulo completo
                String chapterUrl = _convertToChapterUrl(cita, reference);
                _openSource([chapterUrl]);
              } else {
                print(
                    '⚠️ No hay cita o referencia disponible para este versículo');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                '📖',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteContent(bool isCompactMode) {
    return Stack(
      children: [
        Column(
          key: const ValueKey('quote'),
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Indicador de inspiración
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: isCompactMode ? 12 : 14,
                  color: const Color(0xFF8B5CF6).withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  'Inspiración',
                  style: TextStyle(
                    fontSize: isCompactMode ? 9 : 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8B5CF6).withOpacity(0.7),
                  ),
                ),
              ],
            ),

            // Texto de la cita - CLICKEABLE
            Expanded(
              flex: 3,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isCompactMode ? 4.0 : 8.0),
                  child: GestureDetector(
                    onTap: () => _showFullScreenText(
                      context,
                      '"${_quoteData!['quote']}"',
                      '— ${_quoteData!['author'] ?? 'Anónimo'}',
                      false, // isVerse = false
                    ),
                    child: Text(
                      '"${_quoteData!['quote']}"',
                      style: TextStyle(
                        fontSize: isCompactMode ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: isCompactMode ? 1.2 : 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: isCompactMode ? 3 : null,
                      overflow: isCompactMode ? TextOverflow.ellipsis : null,
                    ),
                  ),
                ),
              ),
            ),

            // Autor de la cita
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isCompactMode ? 8 : 10,
                  vertical: isCompactMode ? 2 : 3),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isCompactMode ? 12 : 15),
              ),
              child: Text(
                '— ${_quoteData!['author'] ?? 'Anónimo'}',
                style: TextStyle(
                  fontSize: isCompactMode ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5CF6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        // Botón de fuente para citas inspiracionales
        Positioned(
          bottom: 8,
          left: 8,
          child: GestureDetector(
            onTap: () => _openSource(_quoteData?['sources']),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Text(
                '🔗',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🌟 Mostrar texto en pantalla completa con fondo difuminado
  void _showFullScreenText(
      BuildContext context, String text, String subtitle, bool isVerse) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true, // ✅ PERMITE CERRAR TOCANDO FUERA
      barrierLabel: '',
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullScreenTextDialog(
          text: text,
          subtitle: subtitle,
          isVerse: isVerse,
          animation: animation,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}

// 🎨 Diálogo de pantalla completa elegante
class _FullScreenTextDialog extends StatelessWidget {
  final String text;
  final String subtitle;
  final bool isVerse;
  final Animation<double> animation;

  const _FullScreenTextDialog({
    required this.text,
    required this.subtitle,
    required this.isVerse,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 🌫️ Fondo difuminado elegante - CLICKEABLE PARA CERRAR
          GestureDetector(
            onTap: () =>
                Navigator.of(context).pop(), // 🎯 CERRAR AL TOCAR FONDO
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isVerse
                            ? const Color(
                                0xFF1E3A8A) // Azul profundo para versículos
                            : const Color(0xFF7C3AED) // Morado para citas
                        )
                        .withOpacity(0.85),
                    (isVerse
                            ? const Color(0xFF3730A3) // Azul más claro
                            : const Color(0xFF9333EA) // Morado más claro
                        )
                        .withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ),

          // 📖 Contenido principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Botón de cerrar elegante
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Icon(
                        isVerse ? Icons.menu_book : Icons.auto_awesome,
                        color: Colors.white.withOpacity(0.8),
                        size: 24,
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),

                  // Espacio flexible
                  const Spacer(flex: 1),

                  // 📝 Texto principal con animación - NO CERRAR AL TOCAR
                  GestureDetector(
                    onTap:
                        () {}, // 🛑 ABSORBER toques en la tarjeta (no cerrar)
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Texto principal
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.4,
                              fontFamily: 'serif',
                              fontStyle:
                                  isVerse ? FontStyle.normal : FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),

                          // Subtítulo (referencia o autor)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: (isVerse
                                      ? const Color(0xFF374151)
                                      : const Color(0xFF8B5CF6))
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isVerse
                                    ? const Color(0xFF374151)
                                    : const Color(0xFF8B5CF6),
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 💡 Indicación para cerrar
                  Opacity(
                    opacity: 0.6,
                    child: Text(
                      'Toca fuera del texto para cerrar',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
