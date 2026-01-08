import 'package:intl/intl.dart';

class MonthUtils {
  static const List<String> _spanishMonths = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static const List<String> _englishMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static String getSpanishMonth(DateTime date) {
    return _spanishMonths[date.month - 1];
  }

  static String normalizeMonth(String month) {
    if (month.isEmpty) return _spanishMonths[DateTime.now().month - 1];
    
    final trimmed = month.trim();
    // Check if it's already Spanish (case insensitive)
    for (var m in _spanishMonths) {
      if (m.toLowerCase() == trimmed.toLowerCase()) return m;
    }

    // Check if it's English
    for (int i = 0; i < _englishMonths.length; i++) {
      if (_englishMonths[i].toLowerCase() == trimmed.toLowerCase()) {
        return _spanishMonths[i];
      }
    }

    // Try parsing as integer string
    final int? monthNum = int.tryParse(trimmed);
    if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
      return _spanishMonths[monthNum - 1];
    }

    // Default to current month or return original if no match found (fallback)
    return trimmed; 
  }
}
