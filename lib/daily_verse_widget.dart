import 'package:flutter/material.dart';
import 'dart:async';
import 'calendar_verse_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

    final verseData =
        await CalendarVerseService.getVerseForDate(widget.selectedDate);

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

    print(
        '🔄 Iniciando ciclo de animación - Mostrando: ${_showingVerse ? 'VERSÍCULO' : 'FRASE'}');

    // Mostrar contenido por 10 segundos, luego parpadear y cambiar
    _contentTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        print(
            '⏰ 10 segundos completados - Cambiando de ${_showingVerse ? 'VERSÍCULO' : 'FRASE'} a ${_showingVerse ? 'FRASE' : 'VERSÍCULO'}');
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
        print(
            '🔄 Contenido cambiado a: ${_showingVerse ? 'VERSÍCULO' : 'FRASE'}');
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
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF374151)),
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
            height:
                double.infinity, // Asegurar que use todo el espacio disponible
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
              duration:
                  const Duration(milliseconds: 600), // Transición más suave
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
              child:
                  _showingVerse ? _buildVerseContent() : _buildQuoteContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseContent() {
    return Stack(
      children: [
        // Contenido principal
        Column(
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
                  color: const Color(0xFF374151).withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Versículo del día',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151).withOpacity(0.7),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 60,
                        ),
                        child: Text(
                          '"${_verseData!['verse']}"',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: null,
                          softWrap: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Referencia bíblica - Texto responsive
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _verseData!['reference'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),

        // Botón de enlace para abrir capítulo completo
        if (_verseData!['reference'] != null &&
            _verseData!['reference'].toString().isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _showChapterDialog(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF374151).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  '📖',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Método para mostrar diálogo de confirmación
  Future<void> _showLinkDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFE2E8F0).withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.open_in_browser,
                    size: 32,
                    color: const Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 16),

                // Título
                Text(
                  '¿Explorar esta inspiración con IA?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Subtítulo
                Text(
                  'La IA de Google te explicará el significado y contexto',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    // Botón Cancelar
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF94A3B8),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Botón Abrir
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _searchQuoteInGoogle(_verseData!['quote'],
                              _verseData!['author'] ?? '');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64748B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Abrir',
                          style: TextStyle(
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
        );
      },
    );
  }

  // Método para buscar la frase en Google con modo AI
  Future<void> _searchQuoteInGoogle(String quote, String author) async {
    try {
      // Construir la búsqueda optimizada para el modo AI de Google
      String searchQuery =
          'Dame fuentes y busca en la red la frase "$quote" $author por favor';

      print('🤖 Buscando con IA de Google: $searchQuery');

      // Intentar diferentes URLs para modo IA
      List<String> aiUrls = [
        // Método 1: Google search con modo IA (preferido)
        'https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}&udm=14',
        // Método 2: Gemini directamente
        'https://gemini.google.com/?q=${Uri.encodeComponent(searchQuery)}',
        // Método 3: Búsqueda normal optimizada para IA
        'https://www.google.com/search?q=${Uri.encodeComponent(searchQuery)}',
      ];

      bool launched = false;

      // Intentar cada URL hasta que una funcione
      for (int i = 0; i < aiUrls.length && !launched; i++) {
        final Uri uri = Uri.parse(aiUrls[i]);
        String urlType = i == 0
            ? 'Google IA'
            : i == 1
                ? 'Gemini'
                : 'Google normal';

        try {
          print('🔄 Intentando abrir $urlType...');

          // Intento 1: Modo plataforma por defecto
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
            launched = true;
            print('✅ $urlType abierto con platformDefault');
            break;
          }

          // Intento 2: Modo aplicación externa
          if (!launched) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ $urlType abierto con externalApplication');
            break;
          }
        } catch (e) {
          print('❌ $urlType falló: $e');
          // Continuar con la siguiente URL
        }
      }

      // Intento final: navegador interno con la primera URL
      if (!launched) {
        try {
          final Uri uri = Uri.parse(aiUrls[0]);
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
          launched = true;
          print('✅ Google IA abierto con inAppWebView (último recurso)');
        } catch (e) {
          print('❌ inAppWebView también falló: $e');
        }
      }

      // Si nada funcionó, mostrar error
      if (!launched) {
        throw Exception('Todos los métodos de apertura fallaron');
      }
    } catch (e) {
      print('💥 Error al buscar con IA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No se pudo abrir la búsqueda con IA\n(Puede ser limitación del emulador)'),
            backgroundColor: Colors.red.shade400,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Método para mostrar diálogo de confirmación para capítulo bíblico
  Future<void> _showChapterDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF374151).withOpacity(0.1),
                  const Color(0xFF374151).withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.menu_book,
                    size: 32,
                    color: const Color(0xFF374151),
                  ),
                ),

                const SizedBox(height: 16),

                // Título
                Text(
                  '¿Leer el capítulo completo?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Subtítulo
                Text(
                  'Se abrirá el capítulo completo de ${_verseData!['reference']} en la Biblia online',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF374151).withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Botones
                Row(
                  children: [
                    // Botón Cancelar
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF374151).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Botón Abrir
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openFullChapter(_verseData!['reference']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF374151),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Leer',
                          style: TextStyle(
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
        );
      },
    );
  }

  // Método para abrir el capítulo completo de la Biblia
  Future<void> _openFullChapter(String reference) async {
    try {
      print('📖 Abriendo capítulo completo: $reference');

      // Parsear la referencia bíblica para obtener solo libro y capítulo (sin versículo)
      String cleanReference = reference.trim();
      String chapterReference = _extractChapterOnly(cleanReference);

      print('📖 Referencia del capítulo: $chapterReference');

      // URLs de diferentes sitios bíblicos para el capítulo completo
      List<String> bibleUrls = [
        // Biblia Gateway - capítulo completo
        'https://www.biblegateway.com/passage/?search=${Uri.encodeComponent(chapterReference)}&version=RVR1960',
        // Biblia online en español - capítulo completo
        'https://www.biblia.es/biblia-buscar-${Uri.encodeComponent(chapterReference.replaceAll(' ', '-').toLowerCase())}',
        // YouVersion Bible - capítulo completo
        'https://www.bible.com/search/bible?q=${Uri.encodeComponent(chapterReference)}',
      ];

      bool launched = false;

      // Intentar cada URL hasta que una funcione
      for (int i = 0; i < bibleUrls.length && !launched; i++) {
        final Uri uri = Uri.parse(bibleUrls[i]);
        String siteName = i == 0
            ? 'Bible Gateway'
            : i == 1
                ? 'Biblia.es'
                : 'YouVersion';

        try {
          print('🔄 Intentando abrir $siteName...');

          // Intento 1: Modo plataforma por defecto
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
            launched = true;
            print('✅ $siteName abierto con platformDefault');
            break;
          }

          // Intento 2: Modo aplicación externa
          if (!launched) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ $siteName abierto con externalApplication');
            break;
          }
        } catch (e) {
          print('❌ $siteName falló: $e');
          // Continuar con la siguiente URL
        }
      }

      // Intento final: navegador interno
      if (!launched) {
        try {
          final Uri uri = Uri.parse(bibleUrls[0]);
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
          launched = true;
          print('✅ Bible Gateway abierto con inAppWebView (último recurso)');
        } catch (e) {
          print('❌ inAppWebView también falló: $e');
        }
      }

      // Si nada funcionó, mostrar error
      if (!launched) {
        throw Exception('Todos los métodos de apertura fallaron');
      }
    } catch (e) {
      print('💥 Error al abrir capítulo bíblico: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No se pudo abrir el capítulo bíblico\n(Puede ser limitación del emulador)'),
            backgroundColor: Colors.red.shade400,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Método para extraer solo el libro y capítulo de una referencia bíblica
  String _extractChapterOnly(String reference) {
    try {
      // Ejemplos de referencias: "Salmo 95:2", "Juan 3:16", "1 Corintios 13:4-7"

      // Buscar el último número seguido de dos puntos
      RegExp regExp = RegExp(r'^(.+?)(\d+):(\d+)');
      Match? match = regExp.firstMatch(reference.trim());

      if (match != null) {
        String book = match.group(1)?.trim() ?? '';
        String chapter = match.group(2) ?? '';

        // Retornar solo libro y capítulo
        return '$book $chapter';
      }

      // Si no encuentra el patrón, devolver la referencia original
      return reference;
    } catch (e) {
      print('❌ Error parseando referencia bíblica: $e');
      return reference;
    }
  }

  Widget _buildQuoteContent() {
    // Solo mostrar si hay cita disponible
    if (_verseData!['quote'] == null ||
        _verseData!['quote'].toString().isEmpty) {
      return _buildVerseContent(); // Volver al versículo si no hay cita
    }

    return Stack(
      children: [
        // Contenido principal
        Column(
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
                  Icons.psychology,
                  size: 14,
                  color: const Color(0xFF64748B).withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Inspiración',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B).withOpacity(0.8),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 60,
                        ),
                        child: Text(
                          '"${_verseData!['quote']}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: null,
                          softWrap: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Autor - Texto responsive
            if (_verseData!['author'] != null &&
                _verseData!['author'].toString().isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '— ${_verseData!['author']}',
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),

        // Emoji de enlace en esquina inferior izquierda
        if (_verseData!['cita'] != null &&
            _verseData!['cita'].toString().isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _showLinkDialog(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF94A3B8),
                    width: 1,
                  ),
                ),
                child: const Text(
                  '🔗',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
