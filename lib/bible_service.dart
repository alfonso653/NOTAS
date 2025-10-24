import 'dart:convert';
import 'package:flutter/services.dart';

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
}

class BibleService {
  static BibleService? _instance;
  static BibleService get instance => _instance ??= BibleService._();
  BibleService._();

  List<BibleVerse> _verses = [];
  bool _isLoaded = false;

  Future<void> loadBible() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString('assets/data/biblia.json');
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
      if (bookName.startsWith(normalizedQuery) && !seenBooks.contains(bookName)) {
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

  List<BibleVerse> _searchChapterVerses(String book, String chapter, int maxResults) {
    final normalizedBook = _normalizeBookName(book);
    
    return _verses.where((verse) {
      final bookName = _normalizeBookName(verse.bookName.toLowerCase());
      return bookName == normalizedBook && verse.chapter == chapter;
    }).take(maxResults).toList();
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
}