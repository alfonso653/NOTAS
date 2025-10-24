import 'package:flutter/material.dart';
import 'bible_service.dart';

class BibleAutoCompleteWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(BibleVerse) onVerseSelected;
  final VoidCallback onCancel;

  const BibleAutoCompleteWidget({
    Key? key,
    required this.controller,
    required this.onVerseSelected,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<BibleAutoCompleteWidget> createState() =>
      _BibleAutoCompleteWidgetState();
}

class _BibleAutoCompleteWidgetState extends State<BibleAutoCompleteWidget> {
  List<BibleVerse> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text;

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // Buscar sugerencias
    final suggestions =
        BibleService.instance.searchSuggestions(query, maxResults: 8);

    setState(() {
      _suggestions = suggestions;
      _showSuggestions = suggestions.isNotEmpty;
    });
  }

  String _formatSuggestion(BibleVerse verse, String query) {
    final cleanQuery = query.trim().toLowerCase();

    // Caso 1: Solo escribió libro ("j", "juan") → mostrar solo nombre del libro
    if (!cleanQuery.contains(' ')) {
      return verse.bookName;
    }

    final parts = cleanQuery.split(' ');

    // Caso 2: Escribió libro + capítulo ("juan 3") → mostrar todos los versículos
    if (parts.length >= 2 && !cleanQuery.contains(':')) {
      final chapterPart = parts[1];

      // Si no hay capítulo específico, mostrar capítulos disponibles
      if (chapterPart.isEmpty) {
        return '${verse.bookName} ${verse.chapter}';
      }

      // Si hay capítulo, mostrar versículos del capítulo
      return '${verse.reference} - ${verse.text.length > 60 ? verse.text.substring(0, 60) + '...' : verse.text}';
    }

    // Caso 3: Referencia completa ("juan 3:16") → mostrar versículo específico
    final text = verse.text.length > 80
        ? '${verse.text.substring(0, 80)}...'
        : verse.text;
    return '${verse.reference} - $text';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input field con estilo bíblico
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // Amarillo suave
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB45309), width: 2),
              ),
              child: TextField(
                controller: widget.controller,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Ej: juan 3:16, salmos 23, genesis...',
                  hintStyle: TextStyle(
                    color: Colors.brown.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                  prefixIcon: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFFB45309),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFB45309)),
                    onPressed: widget.onCancel,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Suggestions dropdown
            if (_showSuggestions) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final verse = _suggestions[index];
                    final displayText =
                        _formatSuggestion(verse, widget.controller.text);

                    return InkWell(
                      onTap: () => widget.onVerseSelected(verse),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: index < _suggestions.length - 1
                              ? const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFF3F4F6),
                                    width: 1,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 16,
                                color: Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                displayText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Color(0xFFB45309),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
