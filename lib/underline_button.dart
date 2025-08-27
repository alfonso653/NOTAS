import 'package:flutter/material.dart';

class UnderlineButton extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<Color> onColorSelected;
  const UnderlineButton({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.onColorSelected,
    super.key,
  });

  static const List<Color> pastelColors = [
    Color(0xFFB39DDB), // lila
    Color(0xFFFFF59D), // amarillo
    Color(0xFF80DEEA), // celeste
    Color(0xFFFFAB91), // coral
    Color(0xFFA5D6A7), // verde
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
                color: selected ? color : Colors.grey.shade300,
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
              'U',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 22,
                color: selected ? Colors.white : Colors.black87,
                decoration: TextDecoration.underline,
                decorationColor: selected ? Colors.white : color,
                decorationThickness: 2.5,
                letterSpacing: 2,
              ),
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