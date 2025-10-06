import 'package:flutter/material.dart';
import 'underline_button.dart';

// Clase para el formato de texto, compatible con la lógica de resaltado, subrayado y negrita
class TextFormatValue {
  final bool bold;
  final bool underline;
  final Color underlineColor;
  final bool highlight;
  final Color highlightColor;
  final int fontSize;
  final int tabIndex;
  final Color inkColor;
  // Nuevas herramientas de dibujo libre
  final bool pencil;
  final Color pencilColor;
  final bool pen;
  final Color penColor;
  final bool crayon;
  final Color crayonColor;
  final bool brush;
  final Color brushColor;
  // Borrador para eliminar trazos
  final bool eraser;

  const TextFormatValue({
    this.bold = false,
    this.underline = false,
    this.underlineColor = const Color(0xFF000000),
    this.highlight = false,
    this.highlightColor = const Color(0xFFFFFF00),
    this.fontSize = 16,
    this.tabIndex = 0,
    this.inkColor = const Color(0xFF000000),
    // Valores por defecto para las nuevas herramientas
    this.pencil = false,
    this.pencilColor = const Color(0xFF424242),
    this.pen = false,
    this.penColor = const Color(0xFF1976D2),
    this.crayon = false,
    this.crayonColor = const Color(0xFF4CAF50),
    this.brush = false,
    this.brushColor = const Color(0xFF9C27B0),
    this.eraser = false,
  });

  TextFormatValue copyWith({
    bool? bold,
    bool? underline,
    Color? underlineColor,
    bool? highlight,
    Color? highlightColor,
    int? fontSize,
    int? tabIndex,
    Color? inkColor,
    // Nuevos parámetros para las herramientas de dibujo
    bool? pencil,
    Color? pencilColor,
    bool? pen,
    Color? penColor,
    bool? crayon,
    Color? crayonColor,
    bool? brush,
    Color? brushColor,
    bool? eraser,
  }) {
    return TextFormatValue(
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      underlineColor: underlineColor ?? this.underlineColor,
      highlight: highlight ?? this.highlight,
      highlightColor: highlightColor ?? this.highlightColor,
      fontSize: fontSize ?? this.fontSize,
      tabIndex: tabIndex ?? this.tabIndex,
      inkColor: inkColor ?? this.inkColor,
      // Nuevas propiedades
      pencil: pencil ?? this.pencil,
      pencilColor: pencilColor ?? this.pencilColor,
      pen: pen ?? this.pen,
      penColor: penColor ?? this.penColor,
      crayon: crayon ?? this.crayon,
      crayonColor: crayonColor ?? this.crayonColor,
      brush: brush ?? this.brush,
      brushColor: brushColor ?? this.brushColor,
      eraser: eraser ?? this.eraser,
    );
  }
}

class TextFormatPanel extends StatefulWidget {
  final VoidCallback onClose;
  final TextFormatValue value;
  final ValueChanged<TextFormatValue>? onChanged;

  const TextFormatPanel({
    Key? key,
    required this.onClose,
    this.value = const TextFormatValue(),
    this.onChanged,
  }) : super(key: key);

  @override
  State<TextFormatPanel> createState() => _TextFormatPanelState();
}

class _TextFormatPanelState extends State<TextFormatPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  late TextFormatValue v;

  @override
  void initState() {
    super.initState();
    v = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  void _set(TextFormatValue next) {
    setState(() => v = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    // Panel con animación de subida y fade (UI intacta)
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onClose,
        child: Align(
          alignment: Alignment.topLeft,
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.only(left: 16, top: 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Botón Negrilla (B)
                    GestureDetector(
                      onTap: () => _set(v.copyWith(bold: !v.bold)),
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: v.bold
                              ? const Color(0xFFFFC107)
                              : const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: v.bold
                                ? Colors.amber.shade700
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'B',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: v.bold ? Colors.white : Colors.black87,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    // Botón Subrayado (U) con selección de color (ya existente)
                    UnderlineButton(
                      selected: v.underline,
                      color: v.underlineColor,
                      onTap: () => _set(v.copyWith(underline: !v.underline)),
                      onColorSelected: (color) => _set(
                        v.copyWith(underline: true, underlineColor: color),
                      ),
                    ),
                    // Botón Resaltado (Highlight) con selección de color pastel
                    HighlightButton(
                      selected: v.highlight,
                      color: v.highlightColor,
                      onTap: () => _set(v.copyWith(highlight: !v.highlight)),
                      onColorSelected: (color) => _set(
                        v.copyWith(highlight: true, highlightColor: color),
                      ),
                    ),
                    // Nuevos botones de dibujo libre
                    PencilButton(
                      selected: v.pencil,
                      color: v.pencilColor,
                      onTap: () => _set(v.copyWith(pencil: !v.pencil)),
                      onColorSelected: (color) => _set(
                        v.copyWith(pencil: true, pencilColor: color),
                      ),
                    ),
                    PenButton(
                      selected: v.pen,
                      color: v.penColor,
                      onTap: () => _set(v.copyWith(pen: !v.pen)),
                      onColorSelected: (color) => _set(
                        v.copyWith(pen: true, penColor: color),
                      ),
                    ),
                    CrayonButton(
                      selected: v.crayon,
                      color: v.crayonColor,
                      onTap: () => _set(v.copyWith(crayon: !v.crayon)),
                      onColorSelected: (color) => _set(
                        v.copyWith(crayon: true, crayonColor: color),
                      ),
                    ),
                    BrushButton(
                      selected: v.brush,
                      color: v.brushColor,
                      onTap: () => _set(v.copyWith(brush: !v.brush)),
                      onColorSelected: (color) => _set(
                        v.copyWith(brush: true, brushColor: color),
                      ),
                    ),
                    // Botón Borrador
                    EraserButton(
                      selected: v.eraser,
                      onTap: () => _set(v.copyWith(eraser: !v.eraser)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para el botón de resaltado con selección de color pastel (UI intacta)
class HighlightButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<Color> onColorSelected;
  const HighlightButton({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.onColorSelected,
    Key? key,
  }) : super(key: key);

  static const List<Color> pastelColors = [
    Color(0xFFFFF9C4), // Amarillo
    Color(0xFFC8E6C9), // Verde
    Color(0xFFB3E5FC), // Azul
    Color(0xFFE1BEE7), // Lila
    Color(0xFFFFCDD2), // Rosa
    Color(0xFFFFE0B2), // Naranja claro
    Color(0xFFB2DFDB), // Menta claro
    Color(0xFFF3E5F5), // Lavanda suave
    Color(0xFFFFECB3), // Crema dorado
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.amber.shade700 : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/crayon.png',
              width: 26,
              height: 26,
              color: selected ? Colors.white : Colors.black54,
            ),
          ),
        ),
        if (selected) ...[
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...pastelColors
                    .map((c) => GestureDetector(
                          onTap: () {
                            print('Color seleccionado: $c'); // Debug
                            onColorSelected(c);
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                // Botón para quitar resaltado
                GestureDetector(
                  onTap: () {
                    print('Quitar resaltado'); // Debug
                    onTap(); // Desactiva el resaltado
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🚫',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Widget para el botón de lápiz (dibujo libre fino)
class PencilButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<Color> onColorSelected;
  const PencilButton({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.onColorSelected,
    Key? key,
  }) : super(key: key);

  static const List<Color> pencilColors = [
    Color(0xFF424242), // Grafito oscuro
    Color(0xFF757575), // Grafito medio
    Color(0xFF9E9E9E), // Grafito claro
    Color(0xFF1976D2), // Azul
    Color(0xFFD32F2F), // Rojo
    Color(0xFF388E3C), // Verde
    Color(0xFFF57C00), // Naranja
    Color(0xFF7B1FA2), // Morado
    Color(0xFF5D4037), // Marrón
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '✏️',
              style: TextStyle(
                fontSize: 24,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
        if (selected) ...[
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...pencilColors
                    .map((c) => GestureDetector(
                          onTap: () => onColorSelected(c),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                // Botón para quitar lápiz
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🚫',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Widget para el botón de lapicero (dibujo libre medio)
class PenButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<Color> onColorSelected;
  const PenButton({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.onColorSelected,
    Key? key,
  }) : super(key: key);

  static const List<Color> penColors = [
    Color(0xFF000000), // Negro
    Color(0xFF1976D2), // Azul clásico
    Color(0xFFD32F2F), // Rojo
    Color(0xFF388E3C), // Verde
    Color(0xFF7B1FA2), // Morado
    Color(0xFFF57C00), // Naranja
    Color(0xFF795548), // Marrón
    Color(0xFF607D8B), // Azul gris
    Color(0xFFE91E63), // Rosa
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.blue.shade700 : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '🖊️',
              style: TextStyle(
                fontSize: 24,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
        if (selected) ...[
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...penColors
                    .map((c) => GestureDetector(
                          onTap: () => onColorSelected(c),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                // Botón para quitar lapicero
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🚫',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Widget para el botón de crayola (dibujo libre grueso) - COLOR VERDE
class CrayonButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<Color> onColorSelected;
  const CrayonButton({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.onColorSelected,
    Key? key,
  }) : super(key: key);

  static const List<Color> crayonColors = [
    Color(0xFFFF1744), // Rojo vibrante
    Color(0xFFFF9800), // Naranja vibrante
    Color(0xFFFFEB3B), // Amarillo vibrante
    Color(0xFF4CAF50), // Verde vibrante
    Color(0xFF2196F3), // Azul vibrante
    Color(0xFF9C27B0), // Morado vibrante
    Color(0xFFE91E63), // Rosa vibrante
    Color(0xFF795548), // Marrón
    Color(0xFF607D8B), // Gris azulado
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.green.shade700 : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '🖍️',
              style: TextStyle(
                fontSize: 24,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
        if (selected) ...[
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...crayonColors
                    .map((c) => GestureDetector(
                          onTap: () => onColorSelected(c),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                // Botón para quitar crayola
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🚫',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Widget para el botón de pincel (dibujo libre artístico)
class BrushButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<Color> onColorSelected;
  const BrushButton({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.onColorSelected,
    Key? key,
  }) : super(key: key);

  static const List<Color> brushColors = [
    Color(0xFF8E24AA), // Morado artístico
    Color(0xFF3F51B5), // Índigo
    Color(0xFF00ACC1), // Cian
    Color(0xFF43A047), // Verde bosque
    Color(0xFFFB8C00), // Ámbar
    Color(0xFFE53935), // Rojo fuego
    Color(0xFFAD1457), // Rosa profundo
    Color(0xFF6D4C41), // Marrón chocolate
    Color(0xFF546E7A), // Azul gris
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.purple.shade700 : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '🖌️',
              style: TextStyle(
                fontSize: 24,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
        if (selected) ...[
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...brushColors
                    .map((c) => GestureDetector(
                          onTap: () => onColorSelected(c),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                // Botón para quitar pincel
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '🚫',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Widget para el botón borrador
class EraserButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const EraserButton({
    required this.selected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.grey.shade400 : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Image.asset(
          'assets/borrador.png',
          width: 24,
          height: 24,
          color: selected ? Colors.grey.shade700 : Colors.black54,
        ),
      ),
    );
  }
}
