import 'package:flutter/material.dart';
import 'bible_service.dart';

class BibleAutoCompleteWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(BibleVerse) onVerseSelected;
  final Function(List<BibleVerse>)?
      onMultipleVersesSelected; // Nueva función para múltiples
  final VoidCallback onCancel;

  const BibleAutoCompleteWidget({
    Key? key,
    required this.controller,
    required this.onVerseSelected,
    this.onMultipleVersesSelected,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<BibleAutoCompleteWidget> createState() =>
      _BibleAutoCompleteWidgetState();
}

class _BibleAutoCompleteWidgetState extends State<BibleAutoCompleteWidget>
    with TickerProviderStateMixin {
  List<BibleVerse> _suggestions = [];
  bool _showSuggestions = false;

  // 🎯 Sistema de pestañas
  late TabController _tabController;
  List<BibleVerse> _favoriteVerses = [];
  bool _favoritesLoaded = false;

  // 🎯 Búsqueda por palabras clave y temas
  List<BibleVerse> _keywordResults = [];
  final TextEditingController _keywordController = TextEditingController();
  String _selectedTheme = '';

  // 🎯 Historial de versículos usados
  List<BibleVerse> _historyVerses = [];
  bool _historyLoaded = false;

  // 🎯 Sistema de selección múltiple
  bool _isMultiSelectMode = false;
  Set<String> _selectedVerses = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.controller.addListener(_onTextChanged);
    _loadFavorites();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keywordController.dispose();
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

  Future<void> _loadFavorites() async {
    if (_favoritesLoaded) return;

    final favorites = await BibleService.instance.getFavoriteVerses();
    setState(() {
      _favoriteVerses = favorites;
      _favoritesLoaded = true;
    });
  }

  Future<void> _loadHistory() async {
    if (_historyLoaded) return;

    final history =
        await BibleService.instance.getHistoryVerses(maxResults: 15);
    setState(() {
      _historyVerses = history;
      _historyLoaded = true;
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

  Widget _buildVerseItem(BibleVerse verse, {bool fromFavorites = false}) {
    final displayText = fromFavorites
        ? verse.fullText
        : _formatSuggestion(verse, widget.controller.text);

    final isSelected = _selectedVerses.contains(verse.id);

    return InkWell(
      onTap: () {
        if (_isMultiSelectMode) {
          // Modo selección múltiple: toggle selección
          setState(() {
            if (isSelected) {
              _selectedVerses.remove(verse.id);
            } else {
              _selectedVerses.add(verse.id);
            }
          });
        } else {
          // Modo normal: agregar versículo inmediatamente
          widget.onVerseSelected(verse);
        }
      },
      onLongPress: () {
        // Activar modo selección múltiple
        setState(() {
          _isMultiSelectMode = true;
          _selectedVerses.add(verse.id);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFF3F4F6),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 🎯 Checkbox o icono normal según el modo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isMultiSelectMode && isSelected
                    ? const Color(0xFF059669) // Verde cuando está seleccionado
                    : fromFavorites
                        ? const Color(0xFFFEF3C7) // Dorado para favoritos
                        : const Color(0xFFF3E8FF), // Púrpura para búsqueda
                borderRadius: BorderRadius.circular(8),
                border: _isMultiSelectMode
                    ? Border.all(
                        color: isSelected
                            ? const Color(0xFF059669)
                            : const Color(0xFFD1D5DB),
                        width: 2,
                      )
                    : null,
              ),
              child: Icon(
                _isMultiSelectMode
                    ? (isSelected ? Icons.check : Icons.circle_outlined)
                    : fromFavorites
                        ? Icons.favorite
                        : Icons.menu_book_rounded,
                size: 16,
                color: _isMultiSelectMode && isSelected
                    ? Colors.white
                    : fromFavorites
                        ? Colors.red.shade400
                        : const Color(0xFFB45309),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 🎯 Botón de Favorito
            FutureBuilder<bool>(
              future: BibleService.instance.isFavorite(verse),
              builder: (context, snapshot) {
                final isFavorite = snapshot.data ?? false;
                return GestureDetector(
                  onTap: () async {
                    await BibleService.instance.toggleFavorite(verse);
                    setState(() {}); // Refresh para actualizar el icono
                    _loadFavorites(); // Recargar favoritos
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFavorite
                          ? Colors.red.shade400
                          : const Color(0xFFB45309),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFFB45309),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7, // Altura fija
        child: Stack(
          children: [
            Container(
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
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      border:
                          Border.all(color: const Color(0xFFB45309), width: 2),
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
                          icon:
                              const Icon(Icons.close, color: Color(0xFFB45309)),
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

                  // 🎯 Tab Bar para Búsqueda y Favoritos
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true, // Para permitir scroll horizontal
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search, size: 14),
                              const SizedBox(width: 4),
                              Text('Referencia (${_suggestions.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.topic, size: 14),
                              const SizedBox(width: 4),
                              Text('Temas (${_keywordResults.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history, size: 14),
                              const SizedBox(width: 4),
                              Text('Recientes (${_historyVerses.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite, size: 14),
                              const SizedBox(width: 4),
                              Text('Favoritos (${_favoriteVerses.length})'),
                            ],
                          ),
                        ),
                      ],
                      labelColor: const Color(0xFFB45309),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: const Color(0xFFB45309),
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ),

                  // 🎯 Tab View Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Búsqueda por Referencia
                        _buildSearchTab(),
                        // Tab 2: Búsqueda por Temas/Palabras Clave
                        _buildKeywordTab(),
                        // Tab 3: Historial de Versículos Usados
                        _buildHistoryTab(),
                        // Tab 4: Favoritos
                        _buildFavoritesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🎯 Botón flotante para modo selección múltiple
            if (_isMultiSelectMode && _selectedVerses.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildMultiSelectActionBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectActionBar() {
    final selectedCount = _selectedVerses.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Contador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$selectedCount',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Texto
          Expanded(
            child: Text(
              selectedCount == 1
                  ? '1 versículo seleccionado'
                  : '$selectedCount versículos seleccionados',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),

          // Botón Cancelar
          GestureDetector(
            onTap: () {
              setState(() {
                _isMultiSelectMode = false;
                _selectedVerses.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Botón Agregar
          GestureDetector(
            onTap: () {
              _addSelectedVerses();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    color: Color(0xFF059669),
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Agregar',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSelectedVerses() {
    if (_selectedVerses.isEmpty || widget.onMultipleVersesSelected == null)
      return;

    // Obtener los versículos seleccionados
    final List<BibleVerse> selectedVersesList = [];

    // Buscar en todas las listas posibles
    for (final verseId in _selectedVerses) {
      // Buscar en sugerencias
      final suggestionVerse =
          _suggestions.where((v) => v.id == verseId).firstOrNull;
      if (suggestionVerse != null) {
        selectedVersesList.add(suggestionVerse);
        continue;
      }

      // Buscar en favoritos
      final favoriteVerse =
          _favoriteVerses.where((v) => v.id == verseId).firstOrNull;
      if (favoriteVerse != null) {
        selectedVersesList.add(favoriteVerse);
        continue;
      }

      // Buscar en historial
      final historyVerse =
          _historyVerses.where((v) => v.id == verseId).firstOrNull;
      if (historyVerse != null) {
        selectedVersesList.add(historyVerse);
        continue;
      }

      // Buscar en resultados de palabras clave
      final keywordVerse =
          _keywordResults.where((v) => v.id == verseId).firstOrNull;
      if (keywordVerse != null) {
        selectedVersesList.add(keywordVerse);
        continue;
      }
    }

    // Llamar al callback con los versículos seleccionados
    widget.onMultipleVersesSelected!(selectedVersesList);

    // Salir del modo selección múltiple
    setState(() {
      _isMultiSelectMode = false;
      _selectedVerses.clear();
    });
  }

  // 🎯 Pestaña de Búsqueda
  Widget _buildSearchTab() {
    if (!_showSuggestions || _suggestions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 48,
                color: Color(0xFFD1D5DB),
              ),
              SizedBox(height: 16),
              Text(
                'Escribe para buscar versículos...',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Ejemplos: "juan 3:16", "salmos 23", "genesis"',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final verse = _suggestions[index];
        return _buildVerseItem(verse, fromFavorites: false);
      },
    );
  }

  // 🎯 Pestaña de Favoritos
  Widget _buildFavoritesTab() {
    if (_favoriteVerses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 48,
                color: Color(0xFFD1D5DB),
              ),
              SizedBox(height: 16),
              Text(
                'No tienes versículos favoritos',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Toca el corazón ♥ en cualquier versículo para agregarlo a favoritos',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _favoriteVerses.length,
      itemBuilder: (context, index) {
        final verse = _favoriteVerses[index];
        return _buildVerseItem(verse, fromFavorites: true);
      },
    );
  }

  // 🎯 Pestaña de Búsqueda por Palabras Clave y Temas
  Widget _buildKeywordTab() {
    return Column(
      children: [
        // Input para búsqueda por palabras clave
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), // Verde muy suave
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF059669), width: 2),
          ),
          child: TextField(
            controller: _keywordController,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por palabras: amor, paz, fe...',
              hintStyle: TextStyle(
                color: Colors.green.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.topic_outlined,
                color: Color(0xFF059669),
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search,
                    color: Color(0xFF059669), size: 20),
                onPressed: () => _searchByKeywords(_keywordController.text),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onSubmitted: _searchByKeywords,
          ),
        ),

        // Chips de temas rápidos
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: BibleService.instance.getAvailableThemes().map((theme) {
              final isSelected = _selectedTheme == theme;
              return GestureDetector(
                onTap: () => _searchByTheme(theme),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF059669)
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: Text(
                    theme.capitalize(),
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF374151),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Resultados
        Expanded(
          child: _keywordResults.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.topic_outlined,
                          size: 48,
                          color: Color(0xFFD1D5DB),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Busca versículos por temas',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Usa las palabras clave o selecciona un tema de arriba',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _keywordResults.length,
                  itemBuilder: (context, index) {
                    final verse = _keywordResults[index];
                    return _buildVerseItem(verse, fromFavorites: false);
                  },
                ),
        ),
      ],
    );
  }

  void _searchByKeywords(String keywords) {
    if (keywords.trim().isEmpty) {
      setState(() {
        _keywordResults = [];
        _selectedTheme = '';
      });
      return;
    }

    final results = BibleService.instance.searchByKeywords(keywords);
    setState(() {
      _keywordResults = results;
      _selectedTheme = '';
    });
  }

  void _searchByTheme(String theme) {
    final results = BibleService.instance.searchByTheme(theme);
    setState(() {
      _keywordResults = results;
      _selectedTheme = theme;
      _keywordController.text = theme;
    });
  }

  // 🎯 Pestaña de Historial de Versículos
  Widget _buildHistoryTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: BibleService.instance.getHistoryStats(),
      builder: (context, statsSnapshot) {
        return Column(
          children: [
            // Estadísticas del historial
            if (statsSnapshot.hasData) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF0F9FF), // Azul muy suave
                      const Color(0xFFE0F2FE),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.analytics,
                          color: Color(0xFF0EA5E9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tu actividad bíblica',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0369A1),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                              'Total',
                              '${statsSnapshot.data!['totalVerses']}',
                              Icons.menu_book),
                        ),
                        Expanded(
                          child: _buildStatItem(
                              'Libros',
                              '${statsSnapshot.data!['uniqueBooks']}',
                              Icons.library_books),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (statsSnapshot.data!['totalVerses'] > 0) ...[
                      Text(
                        '📖 Libro más usado: ${statsSnapshot.data!['mostUsedBook']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0369A1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🕒 Última actividad: ${statsSnapshot.data!['recentActivity']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Lista de versículos del historial
            Expanded(
              child: _historyVerses.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: Color(0xFFD1D5DB),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hay versículos recientes',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Los versículos que uses aparecerán aquí para acceso rápido',
                              style: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _historyVerses.length,
                      itemBuilder: (context, index) {
                        final verse = _historyVerses[index];
                        return _buildHistoryVerseItem(verse, index);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF0EA5E9),
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0369A1),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryVerseItem(BibleVerse verse, int index) {
    return InkWell(
      onTap: () => widget.onVerseSelected(verse),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFF3F4F6),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Indicador de posición en el historial
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: index < 3
                    ? const Color(0xFF0EA5E9) // Azul para los 3 más recientes
                    : const Color(0xFFE5E7EB), // Gris para el resto
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: index < 3 ? Colors.white : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verse.reference,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verse.text.length > 80
                        ? '${verse.text.substring(0, 80)}...'
                        : verse.text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 🎯 Botón de Favorito
            FutureBuilder<bool>(
              future: BibleService.instance.isFavorite(verse),
              builder: (context, snapshot) {
                final isFavorite = snapshot.data ?? false;
                return GestureDetector(
                  onTap: () async {
                    await BibleService.instance.toggleFavorite(verse);
                    setState(() {}); // Refresh
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFavorite
                          ? Colors.red.shade400
                          : const Color(0xFF6B7280),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFF0EA5E9),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension para capitalizar strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
