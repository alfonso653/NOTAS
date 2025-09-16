import 'package:flutter/material.dart';
import 'mindmap_model.dart';

/// Widget minimalista para tablero de mapa mental
typedef NodeMovedCallback = void Function(MindMapNode node);
typedef NodeColorChangedCallback = void Function(String nodeId, Color color);

class MindMapBoard extends StatefulWidget {
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;

  /// Colores por nodo (id -> Color). Opcional para compatibilidad hacia atrás.
  final Map<String, Color> nodeColors;

  /// Notifica al padre que un nodo cambió de posición
  final NodeMovedCallback? onNodeMoved;

  /// Notifica al padre que un nodo cambió de color
  final NodeColorChangedCallback? onNodeColorChanged;

  const MindMapBoard({
    Key? key,
    required this.nodes,
    required this.connections,
    this.onNodeMoved,
    this.onNodeColorChanged,
    this.nodeColors = const {},
  }) : super(key: key);

  @override
  State<MindMapBoard> createState() => _MindMapBoardState();
}

class _MindMapBoardState extends State<MindMapBoard> {
  // Estado de arrastre por nodo (evita conflictos entre gestures)
  final Map<String, bool> _draggingNodes = {};
  // Posición del nodo al iniciar el drag (en coordenadas de escena)
  final Map<String, Offset?> _dragStartNodePositions = {};
  // Punto de escena donde empezó el puntero
  final Map<String, Offset?> _dragStartScenePositions = {};

  String? _selectedNodeId;

  // Zoom / Pan
  final double _minZoom = 0.4;
  final double _maxZoom = 2.5;
  late double _zoom;
  late final TransformationController _transformationController;
  final GlobalKey _viewerKey = GlobalKey();

  // Canvas dinámico para evitar que el contenido se recorte
  static const double _minCanvas = 2000.0;
  static const double _canvasPadding = 300.0;

  @override
  void initState() {
    super.initState();
    _zoom = 1.0;
    _transformationController =
        TransformationController(Matrix4.identity()..scale(_zoom));
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Size _computeCanvasSize() {
    if (widget.nodes.isEmpty) return const Size(_minCanvas, _minCanvas);
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;

    for (final n in widget.nodes) {
      minX = n.position.dx < minX ? n.position.dx : minX;
      minY = n.position.dy < minY ? n.position.dy : minY;
      maxX = n.position.dx > maxX ? n.position.dx : maxX;
      maxY = n.position.dy > maxY ? n.position.dy : maxY;
    }

    final width =
        (maxX - minX).abs() + _canvasPadding * 2 + 400; // margen extra
    final height = (maxY - minY).abs() + _canvasPadding * 2 + 400;

    return Size(
      width.isFinite ? width.clamp(_minCanvas, double.infinity) : _minCanvas,
      height.isFinite ? height.clamp(_minCanvas, double.infinity) : _minCanvas,
    );
  }

  /// Convierte un punto global (pantalla) a coordenadas de escena del child de InteractiveViewer
  Offset _globalToScene(Offset globalPosition) {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return globalPosition;
    final local = box.globalToLocal(globalPosition);
    // TransformationController expone toScene
    return _transformationController.toScene(local);
  }

  void _onNodePanStart(MindMapNode node, DragStartDetails details) {
    final scenePoint = _globalToScene(details.globalPosition);
    setState(() {
      _selectedNodeId = node.id;
      _draggingNodes[node.id] = true;
      _dragStartNodePositions[node.id] = node.position;
      _dragStartScenePositions[node.id] = scenePoint;
    });
  }

  void _onNodePanUpdate(MindMapNode node, DragUpdateDetails details) {
    final startNode = _dragStartNodePositions[node.id];
    final startScene = _dragStartScenePositions[node.id];
    if (_draggingNodes[node.id] == true &&
        startNode != null &&
        startScene != null) {
      final currentScene = _globalToScene(details.globalPosition);
      final deltaScene = currentScene - startScene;
      final newPos = startNode + deltaScene;

      setState(() {
        node.position = newPos;
      });

      if (widget.onNodeMoved != null) {
        try {
          final updated = node.copyWith(position: newPos);
          widget.onNodeMoved!(updated);
        } catch (_) {
          widget.onNodeMoved!(node);
        }
      }
    }
  }

  void _onNodePanEndOrCancel(String nodeId) {
    setState(() {
      _draggingNodes[nodeId] = false;
      _dragStartNodePositions[nodeId] = null;
      _dragStartScenePositions[nodeId] = null;
    });
  }

  Future<void> _pickColorForNode(BuildContext context, MindMapNode node) async {
    final colors = <Color>[
      Colors.white,
      Colors.grey.shade100,
      Colors.grey.shade200,
      Colors.yellow.shade100,
      Colors.amber.shade100,
      Colors.orange.shade100,
      Colors.red.shade100,
      Colors.pink.shade100,
      Colors.purple.shade100,
      Colors.deepPurple.shade100,
      Colors.indigo.shade100,
      Colors.blue.shade100,
      Colors.lightBlue.shade100,
      Colors.cyan.shade100,
      Colors.teal.shade100,
      Colors.green.shade100,
      Colors.lime.shade100,
      Colors.brown.shade100,
    ];

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Color del nodo',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final count = (w / 44).floor().clamp(4, 10);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: colors.length,
                    itemBuilder: (ctx, i) {
                      final c = colors[i];
                      final isSelected = (widget.nodeColors[node.id]?.value ??
                              Colors.white.value) ==
                          c.value;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (widget.onNodeColorChanged != null) {
                            widget.onNodeColorChanged!(node.id, c);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.black12,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color:
                                            Colors.blueAccent.withOpacity(0.2),
                                        blurRadius: 8)
                                  ]
                                : [],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
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
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              setState(() {
                _selectedNodeId = null;
              });
            },
            child: InteractiveViewer(
              key: _viewerKey,
              minScale: _minZoom,
              maxScale: _maxZoom,
              panEnabled: true, // pan/zoom siempre activos
              scaleEnabled: true,
              constrained: false, // canvas grande
              boundaryMargin: const EdgeInsets.all(double.infinity),
              transformationController: _transformationController,
              onInteractionUpdate: (_) {
                setState(() {
                  _zoom = _transformationController.value.getMaxScaleOnAxis();
                });
              },
              child: RepaintBoundary(
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Conexiones debajo
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ConnectionsPainter(
                              widget.nodes, widget.connections),
                        ),
                      ),

                      // Nodos encima
                      ...widget.nodes.map((node) {
                        final isSelected = node.id == _selectedNodeId;
                        final bgColor =
                            widget.nodeColors[node.id] ?? Colors.white;

                        return Positioned(
                          key: ValueKey('pos_${node.id}'),
                          left: node.position.dx,
                          top: node.position.dy,
                          child: _DraggableMindMapNode(
                            key: ValueKey('node_${node.id}'),
                            node: node,
                            selected: isSelected,
                            backgroundColor: bgColor,
                            onSelect: () {
                              setState(() => _selectedNodeId = node.id);
                            },
                            onLongPress: () => _pickColorForNode(context, node),
                            onMoveStart: (details) =>
                                _onNodePanStart(node, details),
                            onMoveUpdate: (details) =>
                                _onNodePanUpdate(node, details),
                            onMoveEnd: () => _onNodePanEndOrCancel(node.id),
                            onMoveCancel: () => _onNodePanEndOrCancel(node.id),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraggableMindMapNode extends StatelessWidget {
  final MindMapNode node;
  final bool selected;
  final Color backgroundColor;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;
  final GestureDragStartCallback onMoveStart;
  final GestureDragUpdateCallback onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onMoveCancel;

  const _DraggableMindMapNode({
    required this.node,
    required this.selected,
    required this.backgroundColor,
    required this.onSelect,
    required this.onLongPress,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onMoveCancel,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Importante: no usamos Scrollbar por nodo para evitar PrimaryScrollController conflicts.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      onLongPress: onLongPress,
      onPanStart: onMoveStart,
      onPanUpdate: onMoveUpdate,
      onPanEnd: (_) => onMoveEnd(),
      onPanCancel: onMoveCancel,
      child: Material(
        color: Colors.transparent,
        elevation: selected ? 8 : 2,
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicWidth(
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 60,
              maxWidth: 260,
              minHeight: 40,
              maxHeight: 160,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.blueAccent : Colors.grey.shade300,
                width: selected ? 2.5 : 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.18),
                          blurRadius: 16,
                          spreadRadius: 2)
                    ]
                  : [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: SingleChildScrollView(
              primary:
                  false, // <-- clave para no usar la PrimaryScrollController
              scrollDirection: Axis.vertical,
              child: Text(
                node.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionsPainter extends CustomPainter {
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;

  _ConnectionsPainter(this.nodes, this.connections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    for (final conn in connections) {
      final from = nodes
          .where((n) => n.id == conn.fromId)
          .cast<MindMapNode?>()
          .firstWhere(
            (n) => n != null,
            orElse: () => null,
          );
      final to =
          nodes.where((n) => n.id == conn.toId).cast<MindMapNode?>().firstWhere(
                (n) => n != null,
                orElse: () => null,
              );
      if (from == null || to == null) continue;

      paint.color = conn.color;

      // Puntos aproximados desde el centro del nodo (ajustables)
      final fromOffset = from.position + const Offset(60, 24);
      final toOffset = to.position + const Offset(60, 24);

      canvas.drawLine(fromOffset, toOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) {
    // Re-pintar cuando cambien nodos o conexiones
    return oldDelegate.nodes != nodes || oldDelegate.connections != connections;
  }
}
