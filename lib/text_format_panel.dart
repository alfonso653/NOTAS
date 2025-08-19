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
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header ----------------------------------------------------------
            Row(
              children: [
                _closeButton(),
                const SizedBox(width: 8),
                _titleTab('Título', 0),
                const SizedBox(width: 18),
                _titleTab('Descripción', 1),
              ],
            ),
            const SizedBox(height: 8),
            _thinDivider(),

            // Row 1: B I U S + tamaño ----------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _formatPill(
                    label: 'B',
                    selected: v.bold,
                    onTap: () => _set(v.copyWith(bold: !v.bold)),
                  ),
                  const SizedBox(width: _gap),
                  _formatPill(
                    label: 'I',
                    selected: v.italic,
                    onTap: () => _set(v.copyWith(italic: !v.italic)),
                  ),
                  const SizedBox(width: _gap),
                  _formatPill(
                    label: 'U',
                    selected: v.underline,
                    onTap: () => _set(v.copyWith(underline: !v.underline)),
                  ),
                  const SizedBox(width: _gap),
                  _formatPill(
                    label: 'S',
                    selected: v.strike,
                    onTap: () => _set(v.copyWith(strike: !v.strike)),
                  ),
                  const Spacer(),
                  _fontSizeMenu(),
                ],
              ),
            ),
            _thinDivider(),

            // Row 2: alineación ----------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _iconSquare(
                    icon: Icons.format_align_left,
                    selected: v.align == TextAlign.left,
                    onTap: () => _set(v.copyWith(align: TextAlign.left)),
                  ),
                  const SizedBox(width: _gap),
                  _iconSquare(
                    icon: Icons.format_align_center,
                    selected: v.align == TextAlign.center,
                    onTap: () => _set(v.copyWith(align: TextAlign.center)),
                  ),
                  const SizedBox(width: _gap),
                  _iconSquare(
                    icon: Icons.format_align_right,
                    selected: v.align == TextAlign.right,
                    onTap: () => _set(v.copyWith(align: TextAlign.right)),
                  ),
                  const SizedBox(width: _gap),
                  _iconSquare(
                    icon: Icons.format_align_justify,
                    selected: v.align == TextAlign.justify,
                    onTap: () => _set(v.copyWith(align: TextAlign.justify)),
                  ),
                ],
              ),
            ),
            _thinDivider(),

            // Row 3: listas / indent / pincel / color ------------------------
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _iconSquare(
                    icon: Icons.format_list_bulleted,
                    selected: v.bulleted,
                    onTap: () => _set(
                      v.copyWith(bulleted: !v.bulleted, numbered: false),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  _iconSquare(
                    icon: Icons.format_list_numbered,
                    selected: v.numbered,
                    onTap: () => _set(
                      v.copyWith(numbered: !v.numbered, bulleted: false),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  _iconSquare(
                    icon: Icons.format_indent_decrease,
                    onTap: () =>
                        _set(v.copyWith(indent: (v.indent - 1).clamp(0, 8))),
                  ),
                  const SizedBox(width: _gap),
                  _iconSquare(
                    icon: Icons.format_indent_increase,
                    selected: v.indent > 0,
                    onTap: () =>
                        _set(v.copyWith(indent: (v.indent + 1).clamp(0, 8))),
                  ),
                  const Spacer(),
                  _iconSquare(
                    icon: Icons.brush,
                    onTap: () => _cycleInkColor(),
                  ),
                  const SizedBox(width: _gap),
                  _colorDot(v.inkColor),
                ],
              ),
            ),
          ],
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
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _iconSquare({
    required IconData icon,
    bool selected = false,
    VoidCallback? onTap,
  }) {
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
        // TODO: para usar PNG propios:
        // Reemplaza el Icon(...) por:
        // Image.asset('assets/icons/mi_icono.png', width: 22, height: 22, color: selected ? Colors.white : Colors.black87)
        child: Icon(
          icon,
          size: 22,
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
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
          color: c,
        ),
      ),
    );
  }

  Widget _thinDivider() => Container(height: 1, color: _divider);
}
