import 'dart:convert';
import 'package:flutter/services.dart';

class CalendarVerseService {
  static final Map<String, Map<String, dynamic>> _cache = {};
  
  // Nombres de los archivos JSON por mes
  static const Map<int, String> _monthFiles = {
    1: 'enero',
    2: 'febrero', 
    3: 'marzo',
    4: 'abril',
    5: 'mayo',
    6: 'junio',
    7: 'julio',
    8: 'agosto',
    9: 'septiembre',
    10: 'octubre',
    11: 'noviembre',
    12: 'diciembre',
  };

  /// Obtiene el versículo para una fecha específica
  static Future<Map<String, dynamic>?> getVerseForDate(DateTime date) async {
    try {
      final month = date.month;
      final day = date.day;
      final key = '$month-$day';
      
      // Verificar si ya está en cache
      final monthFile = _monthFiles[month];
      if (monthFile != null && _cache.containsKey(monthFile)) {
        return _cache[monthFile]![key];
      }
      
      // Cargar el archivo JSON del mes
      if (monthFile != null) {
        await _loadMonthData(month, monthFile);
        return _cache[monthFile]?[key];
      }
      
      return null;
    } catch (e) {
      print('Error cargando versículo para $date: $e');
      return null;
    }
  }

  /// Carga los datos de un mes específico
  static Future<void> _loadMonthData(int month, String monthFile) async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/calendar/$monthFile.json');
      final Map<String, dynamic> monthData = json.decode(jsonString);
      _cache[monthFile] = monthData;
    } catch (e) {
      print('Error cargando datos del mes $monthFile: $e');
      _cache[monthFile] = {};
    }
  }

  /// Pre-carga los datos de todos los meses (opcional, para mejor rendimiento)
  static Future<void> preloadAllMonths() async {
    for (final entry in _monthFiles.entries) {
      await _loadMonthData(entry.key, entry.value);
    }
  }

  /// Limpia el cache
  static void clearCache() {
    _cache.clear();
  }
}