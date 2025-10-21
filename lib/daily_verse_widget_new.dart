import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';

class DailyVerseWidget extends StatefulWidget {
  final String text;
  final String subtitle;
  final bool isVerse;

  const DailyVerseWidget({
    super.key,
    required this.text,
    required this.subtitle,
    this.isVerse = true,
  });

  @override
  State<DailyVerseWidget> createState() => _DailyVerseWidgetState();
}

class _DailyVerseWidgetState extends State<DailyVerseWidget>
    with TickerProviderStateMixin {
  late AnimationController particleController;
  late Animation<double> particleAnimation;
  final GlobalKey screenshotKey = GlobalKey();

  String get text => widget.text;
  String get subtitle => widget.subtitle;
  bool get isVerse => widget.isVerse;

  @override
  void initState() {
    super.initState();

    // 🎭 Configurar animaciones de partículas
    particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: particleController,
      curve: Curves.linear,
    ));

    particleController.repeat();
  }

  @override
  void dispose() {
    particleController.dispose();
    super.dispose();
  }

  // 📸 Función mejorada para compartir con screenshot
  Future<void> _shareContent(String text, String subtitle, bool isVerse) async {
    try {
      print('🔄 Iniciando captura de screenshot...');
      
      final RenderRepaintBoundary boundary = screenshotKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      // Capturar el widget como imagen
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      print('📸 Imagen capturada con éxito');
      
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List imageBytes = byteData.buffer.asUint8List();
        print('💾 Bytes de imagen generados: ${imageBytes.length} bytes');
        
        // Guardar en directorio temporal
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = 'verse_${DateTime.now().millisecondsSinceEpoch}.png';
        final File imageFile = File('${tempDir.path}/$fileName');
        
        await imageFile.writeAsBytes(imageBytes);
        print('📁 Imagen guardada en: ${imageFile.path}');
        
        // Compartir la imagen
        final XFile xFile = XFile(imageFile.path);
        await Share.shareXFiles(
          [xFile],
          text: 'Compartido desde app de notas',
          subject: isVerse ? 'Versículo del día' : 'Reflexión del día',
        );
        
        print('✅ Imagen compartida exitosamente');
      } else {
        print('❌ Error: No se pudieron obtener los bytes de la imagen');
        _fallbackTextShare(text, subtitle);
      }
    } catch (e, stackTrace) {
      print('❌ Error capturando screenshot: $e');
      print('📋 Stack trace: $stackTrace');
      _fallbackTextShare(text, subtitle);
    }
  }

  // 📝 Compartir como texto de respaldo
  void _fallbackTextShare(String text, String subtitle) {
    print('📝 Usando compartir como texto de respaldo');
    Share.share(
      '$text\n\n$subtitle',
      subject: isVerse ? 'Versículo del día' : 'Reflexión del día',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 🌫️ Fondo difuminado elegante - CLICKEABLE PARA CERRAR
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isVerse
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFF7C3AED))
                        .withOpacity(0.85),
                    (isVerse
                            ? const Color(0xFF3730A3)
                            : const Color(0xFF9333EA))
                        .withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ),

          // ✨ Partículas flotantes
          ...List.generate(20, (index) {
            final random = Random();
            return Positioned(
              left: random.nextDouble() * 300,
              top: random.nextDouble() * 600,
              child: AnimatedBuilder(
                animation: particleAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      sin(particleAnimation.value * 2 + index) * 20,
                      particleAnimation.value * 50 - 25,
                    ),
                    child: Opacity(
                      opacity: 0.1 + (sin(particleAnimation.value + index) * 0.1),
                      child: Icon(
                        isVerse ? Icons.auto_awesome : Icons.bubble_chart,
                        color: Colors.white,
                        size: 12 + (sin(particleAnimation.value + index) * 4),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // 📱 Contenido principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botones superiores: Compartir y Cerrar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 📱 Botón de compartir
                      IconButton(
                        onPressed: () => _shareContent(text, subtitle, isVerse),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Compartir',
                      ),
                      // 📖 Ícono central
                      Icon(
                        isVerse ? Icons.menu_book : Icons.auto_awesome,
                        color: Colors.white.withOpacity(0.8),
                        size: 24,
                      ),
                      // ❌ Botón de cerrar
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 📝 Texto principal - NO CERRAR AL TOCAR
                  GestureDetector(
                    onTap: () {}, // Absorber toques
                    child: RepaintBoundary(
                      key: screenshotKey,
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
                                fontStyle: isVerse ? FontStyle.normal : FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 20),

                            // Subtítulo estilizado
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  ),

                  const SizedBox(height: 40),

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