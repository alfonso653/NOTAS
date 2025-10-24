import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 🎨 Generador de imágenes elegantes para versículos y citas
/// 
/// Crea imágenes PNG personalizadas con texto, fondo degradado,
/// y opciones de personalización para compartir en redes sociales.
class VerseImageGenerator {
  /// 📐 Dimensiones estándar para redes sociales
  static const double defaultWidth = 1080.0;
  static const double defaultHeight = 1080.0;
  
  /// 🎨 Colores temáticos predefinidos
  static const Map<String, List<Color>> themes = {
    'verse': [
      Color(0xFF1E3A8A), // Azul profundo
      Color(0xFF3730A3), // Azul vibrante
    ],
    'quote': [
      Color(0xFF7C3AED), // Morado profundo  
      Color(0xFF9333EA), // Morado vibrante
    ],
    'sunrise': [
      Color(0xFFEF4444), // Rojo amanecer
      Color(0xFFF59E0B), // Amarillo dorado
    ],
    'nature': [
      Color(0xFF10B981), // Verde esmeralda
      Color(0xFF059669), // Verde profundo  
    ],
    'ocean': [
      Color(0xFF0EA5E9), // Azul océano
      Color(0xFF0284C7), // Azul profundo
    ],
  };

  /// 📸 Genera una imagen PNG con el texto y configuraciones especificadas
  /// 
  /// [text] - Texto principal del versículo o cita
  /// [subtitle] - Referencia bíblica o autor
  /// [isVerse] - true para versículos, false para citas
  /// [theme] - Tema de colores ('verse', 'quote', 'sunrise', 'nature', 'ocean')
  /// [width] - Ancho de la imagen (por defecto 1080)
  /// [height] - Alto de la imagen (por defecto 1080)
  /// [watermark] - Texto de marca de agua opcional
  static Future<File?> generateVerseImage({
    required String text,
    required String subtitle,
    required bool isVerse,
    String theme = 'verse',
    double width = defaultWidth,
    double height = defaultHeight,
    String? watermark,
  }) async {
    try {
      print('🎨 Iniciando generación de imagen...');
      print('📝 Texto: ${text.substring(0, 30)}...');
      print('🏷️ Subtítulo: $subtitle');
      print('🎭 Tema: $theme');

      // Configurar el lienzo
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(width, height);

      // Obtener colores del tema
      final themeColors = themes[theme] ?? themes[isVerse ? 'verse' : 'quote']!;
      
      // 🌈 Dibujar fondo degradado
      final backgroundPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themeColors,
        ).createShader(Rect.fromLTWH(0, 0, width, height));
      
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

      // 🎭 Añadir textura sutil (círculos decorativos)
      _drawDecorativeElements(canvas, size, themeColors);

      // 📝 Configurar estilos de texto
      final mainTextStyle = TextStyle(
        color: Colors.white,
        fontSize: _calculateFontSize(text, width),
        fontWeight: FontWeight.w600,
        fontFamily: 'serif',
        height: 1.4,
      );

      final subtitleTextStyle = TextStyle(
        color: Colors.white.withOpacity(0.9),
        fontSize: _calculateFontSize(text, width) * 0.6,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
      );

      final watermarkTextStyle = TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 24,
        fontWeight: FontWeight.w400,
      );

      // 📐 Calcular áreas de texto
      final padding = width * 0.08; // 8% de padding
      final textArea = Size(width - (padding * 2), height - (padding * 2));
      
      // 📝 Dibujar texto principal
      final mainTextPainter = TextPainter(
        text: TextSpan(text: text, style: mainTextStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      
      mainTextPainter.layout(maxWidth: textArea.width);
      
      // 📍 Calcular posición centrada del texto principal
      final mainTextOffset = Offset(
        (width - mainTextPainter.width) / 2,
        (height - mainTextPainter.height) / 2 - 40, // Slightly above center
      );
      
      mainTextPainter.paint(canvas, mainTextOffset);

      // 🏷️ Dibujar subtítulo
      final subtitlePainter = TextPainter(
        text: TextSpan(text: subtitle, style: subtitleTextStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      
      subtitlePainter.layout(maxWidth: textArea.width);
      
      final subtitleOffset = Offset(
        (width - subtitlePainter.width) / 2,
        mainTextOffset.dy + mainTextPainter.height + 40,
      );
      
      subtitlePainter.paint(canvas, subtitleOffset);

      // 💧 Dibujar marca de agua si se especifica
      if (watermark != null && watermark.isNotEmpty) {
        final watermarkPainter = TextPainter(
          text: TextSpan(text: watermark, style: watermarkTextStyle),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        
        watermarkPainter.layout();
        
        final watermarkOffset = Offset(
          (width - watermarkPainter.width) / 2,
          height - padding - watermarkPainter.height,
        );
        
        watermarkPainter.paint(canvas, watermarkOffset);
      }

      // 🎨 Finalizar la imagen
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        print('❌ Error: No se pudo generar ByteData');
        return null;
      }

      // 💾 Guardar archivo
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'verse_${timestamp}.png';
      final file = File('${tempDir.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      print('✅ Imagen generada exitosamente');
      print('📁 Archivo: ${file.path}');
      print('📊 Tamaño: ${bytes.length} bytes');
      
      return file;
      
    } catch (e, stackTrace) {
      print('❌ Error generando imagen: $e');
      print('📋 Stack trace: $stackTrace');
      return null;
    }
  }

  /// 🎭 Dibuja elementos decorativos en el fondo
  static void _drawDecorativeElements(Canvas canvas, Size size, List<Color> colors) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // Círculos decorativos grandes
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.15),
      size.width * 0.25,
      paint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.85),
      size.width * 0.2,
      paint,
    );

    // Círculos más pequeños
    paint.color = Colors.white.withOpacity(0.03);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      size.width * 0.15,
      paint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      size.width * 0.1,
      paint,
    );
  }

  /// 📏 Calcula el tamaño de fuente óptimo basado en la longitud del texto
  static double _calculateFontSize(String text, double canvasWidth) {
    final baseSize = canvasWidth * 0.08; // 8% del ancho como base
    
    if (text.length <= 50) {
      return baseSize; // Texto corto - tamaño completo
    } else if (text.length <= 100) {
      return baseSize * 0.85; // Texto medio - reducir un poco
    } else if (text.length <= 200) {
      return baseSize * 0.7; // Texto largo - reducir más
    } else {
      return baseSize * 0.6; // Texto muy largo - tamaño mínimo
    }
  }

  /// 🎨 Obtiene los temas disponibles
  static List<String> getAvailableThemes() {
    return themes.keys.toList();
  }

  /// 🌈 Obtiene los colores de un tema específico
  static List<Color> getThemeColors(String theme) {
    return themes[theme] ?? themes['verse']!;
  }
}