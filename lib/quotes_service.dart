import 'dart:convert';
import 'package:flutter/services.dart';

class QuotesService {
  static List<Map<String, dynamic>>? _quotes;
  static bool _isLoaded = false;

  /// Carga las 365 citas desde el archivo JSON
  static Future<void> loadQuotes() async {
    if (_isLoaded) return;

    try {
      print('📚 Cargando citas inspiracionales...');
      final jsonString = await rootBundle.loadString('assets/data/quotes/365_citas_mezcladas.json');
      final List<dynamic> quotesData = json.decode(jsonString);
      
      _quotes = quotesData.cast<Map<String, dynamic>>();
      _isLoaded = true;
      
      print('✅ Cargadas ${_quotes?.length ?? 0} citas inspiracionales');
    } catch (e) {
      print('❌ Error cargando citas: $e');
      _quotes = [];
      _isLoaded = true;
    }
  }

  /// Obtiene una cita para una fecha específica
  static Future<Map<String, dynamic>?> getQuoteForDate(DateTime date) async {
    await loadQuotes();
    
    if (_quotes == null || _quotes!.isEmpty) {
      return null;
    }

    try {
      // Calcular el día del año (1-365/366)
      final dayOfYear = _calculateDayOfYear(date);
      
      // Asegurar que el índice esté en rango válido
      final index = (dayOfYear - 1) % _quotes!.length;
      
      final quote = _quotes![index];
      
      print('📅 Cita para ${date.day}/${date.month}: "${quote['quote']?.substring(0, 50) ?? 'Sin cita'}..."');
      
      return {
        'quote': quote['quote'] ?? '',
        'author': quote['author'] ?? '',
        'sources': quote['sources'] ?? [],
        'id': quote['id'] ?? index + 1,
      };
    } catch (e) {
      print('❌ Error obteniendo cita para $date: $e');
      return null;
    }
  }

  /// Calcula el día del año (1-365/366)
  static int _calculateDayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final difference = date.difference(startOfYear).inDays + 1;
    return difference;
  }

  /// Obtiene una cita aleatoria
  static Future<Map<String, dynamic>?> getRandomQuote() async {
    await loadQuotes();
    
    if (_quotes == null || _quotes!.isEmpty) {
      return null;
    }

    final randomIndex = DateTime.now().millisecondsSinceEpoch % _quotes!.length;
    return _quotes![randomIndex];
  }

  /// Obtiene el total de citas disponibles
  static Future<int> getTotalQuotes() async {
    await loadQuotes();
    return _quotes?.length ?? 0;
  }

  /// Limpia el cache (útil para recargar datos)
  static void clearCache() {
    _quotes = null;
    _isLoaded = false;
  }
}