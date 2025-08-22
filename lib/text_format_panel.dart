// lib/text_format_panel.dart
import 'package:flutter/material.dart';

/// Estructura con el estado del formato.
/// Úsala para conectar el panel con tu editor.
class TextFormatValue {
  final int tabIndex; // 0: Título, 1: Subtítulo, 2: Encabezado
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final int fontSize;
  final TextAlign align; // left, center, right, justify
  final bool bulleted;
  final bool numbered;
  final int indent; // 0..N
  final Color inkColor;

  const TextFormatValue({
    this.tabIndex = 0,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.fontSize = 16,
    this.align = TextAlign.left,
    this.bulleted = false,
    this.numbered = false,
    this.indent = 0,
    this.inkColor = const Color(0xFF00C853),
  });

  TextFormatValue copyWith({
    int? tabIndex,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    int? fontSize,
    TextAlign? align,
    bool? bulleted,
    bool? numbered,
    int? indent,
    Color? inkColor,
  }) {
    return TextFormatValue(
      tabIndex: tabIndex ?? this.tabIndex,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      fontSize: fontSize ?? this.fontSize,
      align: align ?? this.align,
      bulleted: bulleted ?? this.bulleted,
      numbered: numbered ?? this.numbered,
      indent: indent ?? this.indent,
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

class _TextFormatPanelState extends State<TextFormatPanel> {
  late TextFormatValue v;

  // Estilo visual
  static const _radius = 20.0;
  static const _btn = Size(44, 44);
  static const _gap = 10.0;
  static const _primary = Color(0xFFFFC107); // ámbar elegante para selección
  static const _tileBg = Color(0xFFF6F7F9);
  static const _divider = Color(0xFFEAEAEA);

  @override
  void initState() {
    super.initState();
    v = widget.value;
  }

  void _set(TextFormatValue next) {
    setState(() => v = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    // Panel con solo el botón de negrita "ABC"
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () => _set(v.copyWith(bold: !v.bold)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              color: v.bold ? const Color(0xFFFFC107) : const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: v.bold ? Colors.amber.shade700 : Colors.grey.shade300,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'ABC',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: v.bold ? Colors.white : Colors.black87,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- pieces ----------------

  void _cycleInkColor() {
    const c1 = Color(0xFF00C853); // verde
    const c2 = Color(0xFFFFC107); // ámbar
    const c3 = Color(0xFF2962FF); // azul
    final next = v.inkColor == c1 ? c2 : (v.inkColor == c2 ? c3 : c1);
    _set(v.copyWith(inkColor: next));
  }

  Widget _closeButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onClose,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: _tileBg,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _titleTab(String text, int index) {
    final selected = v.tabIndex == index;
    return GestureDetector(
      onTap: () => _set(v.copyWith(tabIndex: index)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.black87 : Colors.black54,
        ),
      ),
    );
  }

  Widget _formatPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    // Mapeo de label a asset
    final iconMap = {
      'B': 'bold',
      'I': 'italic',
      'U': 'underline',
      'S': 'strikethrough',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: _btn.width,
        height: _btn.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primary : _tileBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Image.asset(
          'assets/fontsabc/${iconMap[label] ?? 'bold'}.png',
          width: 22,
          height: 22,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _iconSquare({
    required IconData icon,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    // Mapeo de iconos a asset
    final iconAsset = {
      Icons.format_align_left: 'align_left',
      Icons.format_align_center: 'align_center',
      Icons.format_align_right: 'align_right',
      Icons.format_align_justify: 'align_justify',
      Icons.format_list_bulleted: 'list_bulleted',
      Icons.format_list_numbered: 'list_numbered',
      Icons.format_indent_decrease: 'indent_decrease',
      Icons.format_indent_increase: 'indent_increase',
      Icons.brush: 'brush',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: _btn.width,
        height: _btn.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primary : _tileBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Image.asset(
          'assets/fontsabc/${iconAsset[icon] ?? 'bold'}.png',
          width: 22,
          height: 22,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _fontSizeMenu() {
    final sizes = [12, 14, 16, 18, 20, 24, 28];
    return PopupMenuButton<int>(
      tooltip: 'Tamaño de fuente',
      position: PopupMenuPosition.under,
      initialValue: v.fontSize,
      itemBuilder: (context) => sizes
          .map((s) => PopupMenuItem<int>(value: s, child: Text('$s')))
          .toList(),
      onSelected: (s) => _set(v.copyWith(fontSize: s)),
      child: Container(
        height: _btn.height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _tileBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/fontsabc/font_size.png',
                width: 22, height: 22, color: Colors.black87),
            const SizedBox(width: 4),
            Text('${v.fontSize}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color c) {
    return Container(
      width: _btn.width,
      height: _btn.height,
      alignment: Alignment.center,
      child: Image.asset('assets/fontsabc/color_picker.png',
          width: 30, height: 30),
    );
  }

  Widget _thinDivider() => Container(height: 1, color: _divider);
}
