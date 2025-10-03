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
    Color(0xFFF8BBD9), // rosa suave
    Color(0xFFE1F5FE), // azul hielo
    Color(0xFFD7CCC8), // beige suave
    Color(0xFFE8F5E8), // menta pálido
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
                ...pastelColors.map((c) => GestureDetector(
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
                        color: color == c ? Colors.black87 : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
                // Botón para quitar subrayado
                GestureDetector(
                  onTap: () {
                    print('Quitar subrayado'); // Debug
                    onTap(); // Desactiva el subrayado
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