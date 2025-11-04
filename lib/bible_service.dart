import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BibleVerse {
  final String bookName;
  final String chapter;
  final String verse;
  final String text;

  BibleVerse({
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      bookName: json['book_name'],
      chapter: json['chapter'],
      verse: json['verse'],
      text: json['text'],
    );
  }

  String get reference => '$bookName $chapter:$verse';
  String get fullText => '$reference - $text';

  // 🎯 ID único para favoritos basado en referencia
  String get id =>
      '${bookName.toLowerCase().replaceAll(' ', '_')}_${chapter}_$verse';
}

class BibleService {
  static BibleService? _instance;
  static BibleService get instance => _instance ??= BibleService._();
  BibleService._();

  List<BibleVerse> _verses = [];
  bool _isLoaded = false;

  // 🎯 Sistema de Favoritos
  Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;

  // 🎯 Sistema de Historial
  List<Map<String, dynamic>> _verseHistory = [];
  bool _historyLoaded = false;

  Future<void> loadBible() async {
    if (_isLoaded) return;

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/biblia.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic> versesJson = jsonData['verses'];

      _verses = versesJson.map((verse) => BibleVerse.fromJson(verse)).toList();
      _isLoaded = true;
      print('📖 Biblia cargada: ${_verses.length} versículos');
    } catch (e) {
      print('❌ Error cargando biblia: $e');
    }
  }

  BibleVerse? searchVerse(String query) {
    if (!_isLoaded || query.trim().isEmpty) return null;

    // Normalizar query: "juan 3:16" -> ["juan", "3", "16"]
    final normalizedQuery = _normalizeQuery(query.trim().toLowerCase());
    if (normalizedQuery == null) return null;

    final bookName = normalizedQuery['book'];
    final chapter = normalizedQuery['chapter'];
    final verse = normalizedQuery['verse'];

    // Buscar versículo exacto
    final foundVerse = _verses.where((v) {
      return _normalizeBookName(v.bookName.toLowerCase()) == bookName &&
          v.chapter == chapter &&
          v.verse == verse;
    }).firstOrNull;

    return foundVerse;
  }

  // 🎯 NUEVA FUNCIONALIDAD: Búsqueda incremental como WhatsApp
  List<BibleVerse> searchSuggestions(String query, {int maxResults = 10}) {
    if (!_isLoaded || query.trim().isEmpty) return [];

    final cleanQuery = query.trim().toLowerCase();

    // Caso 1: Solo libro ("j", "juan", etc.)
    if (!cleanQuery.contains(' ')) {
      return _searchBooks(cleanQuery, maxResults);
    }

    // Caso 2: Libro + espacio pero sin capítulo específico ("juan ", "juan 3", etc.)
    final parts = cleanQuery.split(' ');
    if (parts.length >= 2) {
      final book = parts[0];
      final chapterPart = parts[1];

      // Si no tiene : significa que quiere ver capítulos o versículos de un capítulo
      if (!cleanQuery.contains(':')) {
        // Si chapterPart está vacío, mostrar capítulos disponibles
        if (chapterPart.isEmpty) {
          return _searchChapters(book, maxResults);
        }
        // Si tiene número de capítulo, mostrar todos los versículos de ese capítulo
        return _searchChapterVerses(book, chapterPart, maxResults);
      } else {
        // Caso 3: Referencia completa ("juan 3:16")
        final verse = searchVerse(query);
        return verse != null ? [verse] : [];
      }
    }

    return [];
  }

  List<BibleVerse> _searchBooks(String query, int maxResults) {
    final normalizedQuery = _normalizeBookName(query);
    final results = <BibleVerse>[];
    final seenBooks = <String>{};

    for (final verse in _verses) {
      if (results.length >= maxResults) break;

      final bookName = _normalizeBookName(verse.bookName.toLowerCase());
      if (bookName.startsWith(normalizedQuery) &&
          !seenBooks.contains(bookName)) {
        seenBooks.add(bookName);
        results.add(verse); // Primer versículo del libro
      }
    }

    return results;
  }

  List<BibleVerse> _searchChapters(String book, int maxResults) {
    final normalizedBook = _normalizeBookName(book);
    final results = <BibleVerse>[];
    final seenChapters = <String>{};

    for (final verse in _verses) {
      if (results.length >= maxResults) break;

      final bookName = _normalizeBookName(verse.bookName.toLowerCase());
      if (bookName == normalizedBook) {
        final chapterKey = '${verse.bookName}_${verse.chapter}';
        if (!seenChapters.contains(chapterKey)) {
          seenChapters.add(chapterKey);
          results.add(verse); // Primer versículo del capítulo
        }
      }
    }

    return results;
  }

  List<BibleVerse> _searchChapterVerses(
      String book, String chapter, int maxResults) {
    final normalizedBook = _normalizeBookName(book);

    return _verses
        .where((verse) {
          final bookName = _normalizeBookName(verse.bookName.toLowerCase());
          return bookName == normalizedBook && verse.chapter == chapter;
        })
        .take(maxResults)
        .toList();
  }

  Map<String, String>? _normalizeQuery(String query) {
    // Patrones: "juan 3:16", "1 juan 2:5", "genesis 1:1"
    final regex = RegExp(r'^(\d*\s*\w+)\s+(\d+):(\d+)$');
    final match = regex.firstMatch(query);

    if (match == null) return null;

    final bookPart = match.group(1)?.trim() ?? '';
    final chapter = match.group(2) ?? '';
    final verse = match.group(3) ?? '';

    final normalizedBook = _normalizeBookName(bookPart);

    return {
      'book': normalizedBook,
      'chapter': chapter,
      'verse': verse,
    };
  }

  String _normalizeBookName(String book) {
    final bookMappings = {
      // Mapeos comunes de nombres de libros
      'genesis': 'génesis',
      'exodo': 'éxodo',
      'levitico': 'levítico',
      'numeros': 'números',
      'deuteronomio': 'deuteronomio',
      'josue': 'josué',
      'jueces': 'jueces',
      'rut': 'rut',
      '1 samuel': '1 samuel',
      '2 samuel': '2 samuel',
      '1 reyes': '1 reyes',
      '2 reyes': '2 reyes',
      '1 cronicas': '1 crónicas',
      '2 cronicas': '2 crónicas',
      'esdras': 'esdras',
      'nehemias': 'nehemías',
      'ester': 'ester',
      'job': 'job',
      'salmos': 'salmos',
      'salmo': 'salmos',
      'proverbios': 'proverbios',
      'eclesiastes': 'eclesiastés',
      'cantares': 'cantares',
      'isaias': 'isaías',
      'jeremias': 'jeremías',
      'lamentaciones': 'lamentaciones',
      'ezequiel': 'ezequiel',
      'daniel': 'daniel',
      'oseas': 'oseas',
      'joel': 'joel',
      'amos': 'amós',
      'abdias': 'abdías',
      'jonas': 'jonás',
      'miqueas': 'miqueas',
      'nahum': 'nahum',
      'habacuc': 'habacuc',
      'sofonias': 'sofonías',
      'hageo': 'hageo',
      'zacarias': 'zacarías',
      'malaquias': 'malaquías',
      // Nuevo Testamento
      'mateo': 'mateo',
      'marcos': 'marcos',
      'lucas': 'lucas',
      'juan': 'juan',
      'hechos': 'hechos',
      'romanos': 'romanos',
      '1 corintios': '1 corintios',
      '2 corintios': '2 corintios',
      'galatas': 'gálatas',
      'efesios': 'efesios',
      'filipenses': 'filipenses',
      'colosenses': 'colosenses',
      '1 tesalonicenses': '1 tesalonicenses',
      '2 tesalonicenses': '2 tesalonicenses',
      '1 timoteo': '1 timoteo',
      '2 timoteo': '2 timoteo',
      'tito': 'tito',
      'filemon': 'filemón',
      'hebreos': 'hebreos',
      'santiago': 'santiago',
      '1 pedro': '1 pedro',
      '2 pedro': '2 pedro',
      '1 juan': '1 juan',
      '2 juan': '2 juan',
      '3 juan': '3 juan',
      'judas': 'judas',
      'apocalipsis': 'apocalipsis',
    };

    return bookMappings[book] ?? book;
  }

  // ===========================
  // 🎯 SISTEMA DE FAVORITOS
  // ===========================

  Future<void> _loadFavorites() async {
    if (_favoritesLoaded) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> favoritesList =
          prefs.getStringList('bible_favorites') ?? [];
      _favoriteIds = favoritesList.toSet();
      _favoritesLoaded = true;
      print('💛 Favoritos cargados: ${_favoriteIds.length}');
    } catch (e) {
      print('❌ Error cargando favoritos: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('bible_favorites', _favoriteIds.toList());
    } catch (e) {
      print('❌ Error guardando favoritos: $e');
    }
  }

  /// Verificar si un versículo es favorito
  Future<bool> isFavorite(BibleVerse verse) async {
    await _loadFavorites();
    return _favoriteIds.contains(verse.id);
  }

  /// Agregar versículo a favoritos
  Future<void> addToFavorites(BibleVerse verse) async {
    await _loadFavorites();
    _favoriteIds.add(verse.id);
    await _saveFavorites();
    print('💛 Agregado a favoritos: ${verse.reference}');
  }

  /// Quitar versículo de favoritos
  Future<void> removeFromFavorites(BibleVerse verse) async {
    await _loadFavorites();
    _favoriteIds.remove(verse.id);
    await _saveFavorites();
    print('💔 Quitado de favoritos: ${verse.reference}');
  }

  /// Toggle favorito (agregar si no está, quitar si está)
  Future<bool> toggleFavorite(BibleVerse verse) async {
    final isCurrentlyFavorite = await isFavorite(verse);
    if (isCurrentlyFavorite) {
      await removeFromFavorites(verse);
      return false;
    } else {
      await addToFavorites(verse);
      return true;
    }
  }

  /// Obtener todos los versículos favoritos
  Future<List<BibleVerse>> getFavoriteVerses() async {
    await _loadFavorites();
    await loadBible();

    final favoriteVerses = <BibleVerse>[];
    for (final verse in _verses) {
      if (_favoriteIds.contains(verse.id)) {
        favoriteVerses.add(verse);
      }
    }

    return favoriteVerses;
  }

  /// Limpiar todos los favoritos
  Future<void> clearFavorites() async {
    _favoriteIds.clear();
    await _saveFavorites();
    print('🗑️ Todos los favoritos eliminados');
  }

  // ===========================
  // 🎯 BÚSQUEDA POR PALABRAS CLAVE
  // ===========================

  /// Buscar versículos por palabras clave en el texto
  List<BibleVerse> searchByKeywords(String keywords, {int maxResults = 20}) {
    if (!_isLoaded || keywords.trim().isEmpty) return [];

    final cleanKeywords = keywords.trim().toLowerCase();
    final searchTerms =
        cleanKeywords.split(' ').where((term) => term.length > 2).toList();

    if (searchTerms.isEmpty) return [];

    final results = <BibleVerse>[];

    for (final verse in _verses) {
      final verseText = verse.text.toLowerCase();

      // Contar cuántas palabras clave coinciden
      int matchCount = 0;
      for (final term in searchTerms) {
        if (verseText.contains(term)) {
          matchCount++;
        }
      }

      // Si coinciden todas las palabras clave, agregar a resultados
      if (matchCount == searchTerms.length) {
        results.add(verse);
      }

      // Limitar resultados
      if (results.length >= maxResults) break;
    }

    return results;
  }

  /// Buscar versículos por tema específico
  List<BibleVerse> searchByTheme(String theme, {int maxResults = 15}) {
    final themes = <String, List<String>>{
      'amor': ['amor', 'amar', 'ama', 'amado', 'amamos', 'caridad', 'cariño'],
      'paz': ['paz', 'pacifico', 'tranquilo', 'sosiego', 'calma', 'sereno'],
      'fe': ['fe', 'creer', 'creo', 'creemos', 'confianza', 'confiar', 'fiel'],
      'esperanza': ['esperanza', 'esperar', 'espero', 'esperamos', 'esperar'],
      'sabiduría': [
        'sabiduría',
        'sabio',
        'prudencia',
        'entendimiento',
        'conocimiento'
      ],
      'perdón': ['perdón', 'perdonar', 'perdona', 'perdonamos', 'misericordia'],
      'oración': ['oración', 'orar', 'oro', 'oramos', 'pedir', 'ruego'],
      'gozo': [
        'gozo',
        'alegría',
        'alegrar',
        'regocijar',
        'contento',
        'felicidad'
      ],
      'fortaleza': ['fortaleza', 'fuerte', 'poder', 'fuerza', 'resistencia'],
      'gratitud': [
        'gracias',
        'agradecer',
        'agradecido',
        'gratitud',
        'reconocer'
      ],
    };

    final searchTerms = themes[theme.toLowerCase()] ?? [theme.toLowerCase()];

    final results = <BibleVerse>[];

    for (final verse in _verses) {
      final verseText = verse.text.toLowerCase();

      // Buscar cualquiera de los términos del tema
      for (final term in searchTerms) {
        if (verseText.contains(term)) {
          results.add(verse);
          break; // Solo agregar una vez por versículo
        }
      }

      if (results.length >= maxResults) break;
    }

    return results;
  }

  /// Obtener temas disponibles
  List<String> getAvailableThemes() {
    return [
      'amor',
      'paz',
      'fe',
      'esperanza',
      'sabiduría',
      'perdón',
      'oración',
      'gozo',
      'fortaleza',
      'gratitud'
    ];
  }

  // ===========================
  // 🎯 SISTEMA DE HISTORIAL
  // ===========================

  Future<void> _loadHistory() async {
    if (_historyLoaded) return;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> historyJson =
          prefs.getStringList('bible_history') ?? [];

      _verseHistory = historyJson.map((json) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
            (jsonDecode(json) as Map).cast<String, dynamic>());
        return data;
      }).toList();

      _historyLoaded = true;
      print('📚 Historial cargado: ${_verseHistory.length} entradas');
    } catch (e) {
      print('❌ Error cargando historial: $e');
      _verseHistory = [];
    }
  }

  Future<void> _saveHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> historyJson =
          _verseHistory.map((entry) => jsonEncode(entry)).toList();

      await prefs.setStringList('bible_history', historyJson);
    } catch (e) {
      print('❌ Error guardando historial: $e');
    }
  }

  /// Agregar versículo al historial cuando se usa
  Future<void> addToHistory(BibleVerse verse) async {
    await _loadHistory();

    final now = DateTime.now();
    final entry = {
      'verseId': verse.id,
      'reference': verse.reference,
      'text': verse.text,
      'bookName': verse.bookName,
      'chapter': verse.chapter,
      'verse': verse.verse,
      'timestamp': now.millisecondsSinceEpoch,
      'dateString':
          '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
    };

    // Remover entrada anterior si existe (evitar duplicados)
    _verseHistory.removeWhere((item) => item['verseId'] == verse.id);

    // Agregar al inicio (más reciente primero)
    _verseHistory.insert(0, entry);

    // Mantener máximo 50 entradas
    if (_verseHistory.length > 50) {
      _verseHistory = _verseHistory.take(50).toList();
    }

    await _saveHistory();
    print('📖 Agregado al historial: ${verse.reference}');
  }

  /// Obtener historial de versículos usados
  Future<List<Map<String, dynamic>>> getVerseHistory(
      {int maxResults = 20}) async {
    await _loadHistory();

    return _verseHistory.take(maxResults).toList();
  }

  /// Obtener versículos del historial como objetos BibleVerse
  Future<List<BibleVerse>> getHistoryVerses({int maxResults = 20}) async {
    await _loadHistory();

    final historyVerses = <BibleVerse>[];

    for (final entry in _verseHistory.take(maxResults)) {
      try {
        final verse = BibleVerse(
          bookName: entry['bookName'] as String,
          chapter: entry['chapter'] as String,
          verse: entry['verse'] as String,
          text: entry['text'] as String,
        );
        historyVerses.add(verse);
      } catch (e) {
        print('❌ Error procesando entrada del historial: $e');
      }
    }

    return historyVerses;
  }

  /// Limpiar historial
  Future<void> clearHistory() async {
    _verseHistory.clear();
    await _saveHistory();
    print('🗑️ Historial de versículos limpiado');
  }

  /// Obtener estadísticas del historial
  Future<Map<String, dynamic>> getHistoryStats() async {
    await _loadHistory();

    if (_verseHistory.isEmpty) {
      return {
        'totalVerses': 0,
        'uniqueBooks': 0,
        'mostUsedBook': 'Ninguno',
        'recentActivity': 'Sin actividad',
      };
    }

    // Contar libros más usados
    final bookCounts = <String, int>{};
    for (final entry in _verseHistory) {
      final book = entry['bookName'] as String;
      bookCounts[book] = (bookCounts[book] ?? 0) + 1;
    }

    // Encontrar libro más usado
    String mostUsedBook = 'Ninguno';
    int maxCount = 0;
    for (final entry in bookCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostUsedBook = entry.key;
      }
    }

    // Actividad reciente
    final lastEntry = _verseHistory.first;
    final recentActivity = lastEntry['dateString'] as String;

    return {
      'totalVerses': _verseHistory.length,
      'uniqueBooks': bookCounts.length,
      'mostUsedBook': mostUsedBook,
      'recentActivity': recentActivity,
    };
  }
}
