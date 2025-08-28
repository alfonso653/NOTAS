

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

  const TextFormatValue({
    this.bold = false,
    this.underline = false,
    this.underlineColor = const Color(0xFF000000),
    this.highlight = false,
    this.highlightColor = const Color(0xFFFFFF00),
    this.fontSize = 16,
    this.tabIndex = 0,
    this.inkColor = const Color(0xFF000000),
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

  // (Campos de estilo eliminados porque no se usan directamente)

  @override
  void initState() {
    super.initState();
    v = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
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
    // Panel con animación de subida y fade
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: Center(
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón Negrilla (B)
                  GestureDetector(
                    onTap: () => _set(v.copyWith(bold: !v.bold)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: v.bold ? const Color(0xFFFFC107) : const Color(0xFFF6F7F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: v.bold ? Colors.amber.shade700 : Colors.grey.shade300,
                          width: 2,
                        ),
                        boxShadow: [
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
                  // Botón Subrayado (U) con selección de color
                  UnderlineButton(
                    selected: v.underline,
                    color: v.underlineColor,
                    onTap: () => _set(v.copyWith(underline: !v.underline)),
                    onColorSelected: (color) => _set(v.copyWith(underline: true, underlineColor: color)),
                  ),
                  // Botón Resaltado (Highlight) con selección de color pastel
                  HighlightButton(
                    selected: v.highlight,
                    color: v.highlightColor,
                    onTap: () => _set(v.copyWith(highlight: !v.highlight)),
                    onColorSelected: (color) => _set(v.copyWith(highlight: true, highlightColor: color)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



// Widget para el botón de resaltado con selección de color pastel
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
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.amber.shade700 : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.format_color_fill,
              color: selected ? Colors.white : Colors.black54,
              size: 26,
            ),
          ),
        ),
        if (selected)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: pastelColors.map((c) => GestureDetector(
              onTap: () => onColorSelected(c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == c ? Colors.black87 : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )).toList(),
          ),
      ],
    );
  }
}
