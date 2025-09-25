import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // listEquals, mapEquals
import 'mindmap_model.dart';

/// Tablero de mapa mental con nodos arrastrables y edición.
/// - Inmutable: actualizaciones con copyWith + reemplazo.
/// - Claves estables ValueKey(node.id) para evitar asserts de dependents.
/// - Colores por nodo: acepta nodeColors y expone onNodeColorChanged.
/// - onNodeMoved: notifica al terminar el arrastre.
class MindMapBoard extends StatefulWidget {
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;

  /// Mapa de colores por nodo (nodeId -> Color)
  final Map<String, Color>? nodeColors;

  /// Color por defecto para nodos sin entrada en nodeColors
  final Color defaultNodeColor;

  /// Notifica la lista de nodos actualizada (posición/texto)
  final ValueChanged<List<MindMapNode>>? onNodesChanged;

  /// Notifica cuando cambia el texto de un nodo (nodeId, newText)
  final void Function(String nodeId, String newText)? onNodeTextChanged;

  /// Notifica cuando termina de moverse un nodo (instancia actualizada)
  final void Function(MindMapNode updatedNode)? onNodeMoved;

  /// Notifica cuando cambia el color de un nodo (nodeId, color)
  final void Function(String nodeId, Color color)? onNodeColorChanged;

  const MindMapBoard({
    Key? key,
    required this.nodes,
    this.connections = const [],
    this.nodeColors,
    this.defaultNodeColor = Colors.white,
    this.onNodesChanged,
    this.onNodeTextChanged,
    this.onNodeMoved,
    this.onNodeColorChanged,
  }) : super(key: key);

  @override
  State<MindMapBoard> createState() => _MindMapBoardState();
}

class _MindMapBoardState extends State<MindMapBoard> {
  late List<MindMapNode> _nodes;
  late Map<String, MindMapNode> _byId;

  /// Copia local y mutable para reflejar cambios inmediatos en el board
  late Map<String, Color> _nodeColors;

  // Zoom / Pan
  final double _minZoom = 0.4;
  final double _maxZoom = 2.5;
  late double _zoom;
  late final TransformationController _transformationController;
  final GlobalKey _viewerKey = GlobalKey();

  // Para arrastre fluido - evitar setState en cada frame
  String? _draggingNodeId;
  Offset? _dragOffset;

  @override
  void initState() {
    super.initState();
    _zoom = 1.0;
    _transformationController =
        TransformationController(Matrix4.identity()..scale(_zoom));
    _syncFromWidget();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MindMapBoard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sincroniza nodos cuando cambia la referencia de la lista del padre
    if (!identical(oldWidget.nodes, widget.nodes)) {
      _syncNodes();
    }

    // Sincroniza colores si cambió el mapa recibido
    if (!mapEquals(oldWidget.nodeColors, widget.nodeColors)) {
      _syncColors();
      setState(() {}); // refresco visual si los colores cambiaron
    }
  }

  void _syncFromWidget() {
    _syncNodes();
    _syncColors();
  }

  void _syncNodes() {
    _nodes = List<MindMapNode>.from(widget.nodes);
    _byId = {for (final n in _nodes) n.id: n};
  }

  void _syncColors() {
    _nodeColors = Map<String, Color>.from(widget.nodeColors ?? const {});
  }

  void _emit() {
    widget.onNodesChanged?.call(List.unmodifiable(_nodes));
  }

  Size _computeCanvasSize() {
    if (_nodes.isEmpty) return const Size(2000.0, 2000.0);
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final n in _nodes) {
      minX = n.position.dx < minX ? n.position.dx : minX;
      minY = n.position.dy < minY ? n.position.dy : minY;
      maxX = n.position.dx > maxX ? n.position.dx : maxX;
      maxY = n.position.dy > maxY ? n.position.dy : maxY;
    }

    final width = (maxX - minX).abs() + 600 + 400; // margen extra
    final height = (maxY - minY).abs() + 600 + 400;

    return Size(
      width.isFinite ? width.clamp(2000.0, double.infinity) : 2000.0,
      height.isFinite ? height.clamp(2000.0, double.infinity) : 2000.0,
    );
  }

  /// Reemplaza un nodo por id en _nodes y en _byId
  void _replaceNode(MindMapNode updated) {
    final i = _nodes.indexWhere((n) => n.id == updated.id);
    if (i == -1) return;
    setState(() {
      _nodes[i] = updated;
      _byId[updated.id] = updated;
    });
    _emit();
  }

  /// Iniciar arrastre - prepara para movimiento fluido
  void _onDragStart(MindMapNode node, DragStartDetails details) {
    _draggingNodeId = node.id;
    _dragOffset = Offset.zero;
  }

  /// Arrastrar: actualización súper fluida sin setState por frame
  void _onDragUpdate(MindMapNode node, DragUpdateDetails d) {
    if (_draggingNodeId == node.id) {
      _dragOffset = (_dragOffset ?? Offset.zero) + d.delta;
      // Solo actualizar la posición visualmente, sin setState costoso
      setState(() {
        final newPos = node.position + d.delta;
        final updated = node.copyWith(position: newPos);
        final i = _nodes.indexWhere((n) => n.id == updated.id);
        if (i != -1) {
          _nodes[i] = updated;
          _byId[updated.id] = updated;
        }
      });
    }
  }

  /// Finalizar arrastre
  void _onDragEnd(MindMapNode node) {
    _draggingNodeId = null;
    _dragOffset = null;
    // Notificar el cambio final
    final finalNode = _byId[node.id];
    if (finalNode != null) {
      widget.onNodeMoved?.call(finalNode);
      _emit();
    }
  }

  /// Cambio de texto: usa copyWith y notifica opcionalmente al padre
  void _onNodeTextChanged(String nodeId, String newText) {
    final node = _byId[nodeId];
    if (node == null) return;
    final updated = node.copyWith(text: newText);
    _replaceNode(updated);
    widget.onNodeTextChanged?.call(nodeId, newText);
  }

  /// Paleta simple de colores para elegir rápido
  static const List<Color> _palette = <Color>[
    Colors.white,
    Color(0xFFF1F1F1),
    Color(0xFFFFF3CD),
    Color(0xFFD1E7DD),
    Color(0xFFCFE2FF),
    Color(0xFFFFE5E5),
    Color(0xFFFFF0F6),
    Color(0xFFE7E1FF),
    Color(0xFFFFF8E1),
    Color(0xFFE3F2FD),
    Color(0xFFFCE4EC),
    Color(0xFFE8F5E9),
    Color(0xFFFFECB3),
    Color(0xFFBBDEFB),
    Color(0xFFFFCDD2),
  ];

  Future<Color?> _pickColorDialog(BuildContext context, Color initial) async {
    return showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Color del nodo'),
          content: SizedBox(
            width: 320,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((c) {
                final isSel = c.value == initial.value;
                return InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop(c);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel ? Colors.black87 : Colors.black26,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editNodeTextDialog(
    BuildContext context,
    MindMapNode node,
  ) async {
    final controller = TextEditingController(text: node.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nodo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Texto del nodo',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      _onNodeTextChanged(node.id, result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = _computeCanvasSize();
    
    return Column(
      children: [
        // Slider de zoom + centrar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    thumbColor: Colors.blue,
                    activeTrackColor: Colors.blueAccent,
                    inactiveTrackColor: Colors.blueAccent.withOpacity(0.25),
                  ),
                  child: Slider(
                    min: _minZoom,
                    max: _maxZoom,
                    value: _zoom.clamp(_minZoom, _maxZoom),
                    onChanged: (v) {
                      setState(() {
                        _zoom = v;
                        _transformationController.value = Matrix4.identity()
                          ..scale(_zoom);
                      });
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Centrar y ajustar',
                onPressed: () {
                  setState(() {
                    _zoom = 1.0;
                    _transformationController.value = Matrix4.identity();
                  });
                },
                icon: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
        ),

        // Área interactiva del mapa mental
        Expanded(
          child: InteractiveViewer(
            key: _viewerKey,
            minScale: _minZoom,
            maxScale: _maxZoom,
            panEnabled: true,
            scaleEnabled: true,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            transformationController: _transformationController,
            onInteractionUpdate: (_) {
              setState(() {
                _zoom = _transformationController.value.getMaxScaleOnAxis();
              });
            },
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Conexiones entre nodos (líneas)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConnectionsPainter(
                        nodes: _nodes,
                        connections: widget.connections,
                      ),
                    ),
                  ),
          // Nodos
          ..._nodes.map((node) {
            final bgColor = _nodeColors[node.id] ?? widget.defaultNodeColor;
            return Positioned(
              key: ValueKey(node.id), // clave estable por id
              left: node.position.dx,
              top: node.position.dy,
              child: GestureDetector(
                onPanStart: (details) => _onDragStart(node, details),
                onPanUpdate: (d) => _onDragUpdate(node, d),
                onPanEnd: (_) => _onDragEnd(node),
                onTap: () => _editNodeTextDialog(context, node),
                onLongPress: () async {
                  // Pick color y notifica
                  final picked = await _pickColorDialog(context, bgColor);
                  if (picked != null) {
                    setState(() {
                      _nodeColors[node.id] = picked;
                    });
                    widget.onNodeColorChanged?.call(node.id, picked);
                  }
                },
                child: _DefaultNodeBubble(
                  text: node.text,
                  background: bgColor,
                ),
              ),
            );
          }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Punto de anclaje visual del nodo (simple). Si ya tienes tu propio widget, úsalo.
/// Importante: NO usar UniqueKey aquí; usa claves por id en el contenedor padre.
class _DefaultNodeBubble extends StatelessWidget {
  final String text;
  final Color background;
  const _DefaultNodeBubble({
    required this.text,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Dibuja líneas entre nodos según las conexiones
class _ConnectionsPainter extends CustomPainter {
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;

  _ConnectionsPainter({
    required this.nodes,
    required this.connections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final n in nodes) n.id: n};
    for (final c in connections) {
      final from = byId[c.fromId];
      final to = byId[c.toId];
      if (from == null || to == null) continue;

      final paint = Paint()
        ..color = c.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Ajusta estos offsets al centro de tu widget de nodo, si lo necesitas
      final p1 = from.position + const Offset(40, 20);
      final p2 = to.position + const Offset(40, 20);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(p1.dx + 40, p1.dy, p2.dx - 40, p2.dy, p2.dx, p2.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) {
    // Repintar siempre para seguir posiciones/conexiones cambiantes.
    return true;
  }
}
