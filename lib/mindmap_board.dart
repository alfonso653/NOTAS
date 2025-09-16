import 'package:flutter/material.dart';
import 'mindmap_model.dart';

/// Widget minimalista para tablero de mapa mental
typedef NodeMovedCallback = void Function(MindMapNode node);

class MindMapBoard extends StatefulWidget {
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;
  final NodeMovedCallback? onNodeMoved;

  const MindMapBoard({
    Key? key,
    required this.nodes,
    required this.connections,
    this.onNodeMoved,
  }) : super(key: key);

  @override
  State<MindMapBoard> createState() => _MindMapBoardState();
}

class _MindMapBoardState extends State<MindMapBoard> {
  String? _draggingNodeId;
  Offset? _dragStartNodePosition;
  bool _isDraggingNode = false;
  String? _selectedNodeId;
  final double _minZoom = 0.4;
  final double _maxZoom = 2.5;
  late double _zoom;
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _zoom = _minZoom;
    _transformationController = TransformationController(Matrix4.identity()..scale(_zoom));
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Slider de zoom igual al de la nota
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                        _transformationController.value = Matrix4.identity()..scale(_zoom);
                      });
                    },
                  ),
                ),
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
            child: Listener(
              onPointerSignal: (_) {},
              child: StatefulBuilder(
                builder: (context, setSB) {
                  return InteractiveViewer(
                    minScale: _minZoom,
                    maxScale: _maxZoom,
                    panEnabled: !_isDraggingNode && _selectedNodeId == null,
                    scaleEnabled: true,
                    transformationController: _transformationController,
                    onInteractionUpdate: (details) {
                      setState(() {
                        _zoom = _transformationController.value.getMaxScaleOnAxis();
                      });
                    },
                    panAxis: PanAxis.free,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Dibuja las conexiones
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ConnectionsPainter(widget.nodes, widget.connections),
                          ),
                        ),
                        // Dibuja los nodos
                        ...widget.nodes.map((node) {
                          final isSelected = node.id == _selectedNodeId;
                          return Positioned(
                            left: node.position.dx,
                            top: node.position.dy,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                setState(() {
                                  _selectedNodeId = node.id;
                                });
                              },
                              onPanStart: (details) {
                                if (_selectedNodeId == node.id) {
                                  setState(() {
                                    _draggingNodeId = node.id;
                                    _dragStartNodePosition = node.position;
                                    _isDraggingNode = true;
                                  });
                                }
                              },
                              onPanUpdate: (details) {
                                if (_draggingNodeId == node.id && _dragStartNodePosition != null && _selectedNodeId == node.id) {
                                  setState(() {
                                    node.position = _dragStartNodePosition! + details.delta / _zoom;
                                    _dragStartNodePosition = node.position;
                                  });
                                  if (widget.onNodeMoved != null) {
                                    widget.onNodeMoved!(node);
                                  }
                                }
                              },
                              onPanEnd: (_) {
                                setState(() {
                                  _draggingNodeId = null;
                                  _dragStartNodePosition = null;
                                  _isDraggingNode = false;
                                });
                              },
                              child: _MindMapNodeWidget(node: node, selected: isSelected),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MindMapNodeWidget extends StatelessWidget {
  final MindMapNode node;
  final bool selected;
  const _MindMapNodeWidget({required this.node, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: selected ? 8 : 2,
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(minWidth: 60, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.blueAccent : Colors.grey.shade300,
              width: selected ? 2.5 : 1.2,
            ),
            boxShadow: selected
                ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.18), blurRadius: 16, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Text(
            node.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.blueAccent : Colors.black87,
            ),
            softWrap: true,
            overflow: TextOverflow.visible,
            maxLines: 4,
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
    for (final conn in connections) {
      final from = nodes.firstWhere((n) => n.id == conn.fromId,
          orElse: () => nodes.first);
      final to =
          nodes.firstWhere((n) => n.id == conn.toId, orElse: () => nodes.first);
      final paint = Paint()
        ..color = conn.color
        ..strokeWidth = 2.2;
      final fromOffset =
          from.position + const Offset(60, 24); // centro aproximado
      final toOffset = to.position + const Offset(60, 24);
      canvas.drawLine(fromOffset, toOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
