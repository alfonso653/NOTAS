import 'package:flutter/material.dart';
import 'mindmap_model.dart';

/// Widget minimalista para tablero de mapa mental
class MindMapBoard extends StatefulWidget {
  final List<MindMapNode> nodes;
  final List<MindMapConnection> connections;

  const MindMapBoard({
    Key? key,
    required this.nodes,
    required this.connections,
  }) : super(key: key);

  @override
  State<MindMapBoard> createState() => _MindMapBoardState();
}

class _MindMapBoardState extends State<MindMapBoard> {
  String? _draggingNodeId;
  Offset? _dragStartOffset;
  Offset? _nodeStartOffset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        if (_draggingNodeId != null &&
            _dragStartOffset != null &&
            _nodeStartOffset != null) {
          setState(() {
            final node =
                widget.nodes.firstWhere((n) => n.id == _draggingNodeId);
            node.position =
                _nodeStartOffset! + details.localPosition - _dragStartOffset!;
          });
        }
      },
      onPanEnd: (_) {
        setState(() {
          _draggingNodeId = null;
          _dragStartOffset = null;
          _nodeStartOffset = null;
        });
      },
      child: Stack(
        children: [
          // Dibuja las conexiones
          Positioned.fill(
            child: CustomPaint(
              painter: _ConnectionsPainter(widget.nodes, widget.connections),
            ),
          ),
          // Dibuja los nodos
          ...widget.nodes.map((node) {
            return Positioned(
              left: node.position.dx,
              top: node.position.dy,
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _draggingNodeId = node.id;
                    _dragStartOffset = details.localPosition;
                    _nodeStartOffset = node.position;
                  });
                },
                child: _MindMapNodeWidget(node: node),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _MindMapNodeWidget extends StatelessWidget {
  final MindMapNode node;
  const _MindMapNodeWidget({required this.node});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.2),
        ),
        child: Text(
          node.text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
