import 'package:flutter/material.dart';

enum Category {
  supermarket,
  houseBills,
  undefined,
  credito,
  contribuciones,
  education,
  leisure,
  uberEats,
}

extension CategoryExtension on Category {
  String get name {
    switch (this) {
      case Category.supermarket:
        return 'Supermarket';
      case Category.houseBills:
        return 'House Bills';
      case Category.credito:
        return 'Credito';
      case Category.contribuciones:
        return 'Contribuciones';
      case Category.education:
        return 'Education';
      case Category.leisure:
        return 'Leisure';
      case Category.uberEats:
        return 'Uber Eats';
      case Category.undefined:
      default:
        return 'Undefined';
    }
  }

  Color get color {
    switch (this) {
      case Category.supermarket:
        return const Color(0xFFFF9800); // Vibrant Orange
      case Category.houseBills:
        return const Color(0xFF2196F3); // Vibrant Blue
      case Category.credito:
        return const Color(0xFFF44336); // Vibrant Red
      case Category.contribuciones:
        return const Color(0xFF9C27B0); // Vibrant Purple
      case Category.education:
        return const Color(0xFF4CAF50); // Vibrant Green
      case Category.leisure:
        return const Color(0xFFE91E63); // Vibrant Pink
      case Category.uberEats:
        return const Color(0xFFFFC107); // Vibrant Amber
      case Category.undefined:
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }
}

Category categoryFromString(String? categoryString) {
  if (categoryString == null) {
    return Category.undefined;
  }
  switch (categoryString.toLowerCase().trim()) {
    case 'supermarket':
      return Category.supermarket;
    case 'house bills':
      return Category.houseBills;
    case 'credito':
      return Category.credito;
    case 'contribuciones':
      return Category.contribuciones;
    case 'education':
      return Category.education;
    case 'leisure':
      return Category.leisure;
    case 'uber eats':
      return Category.uberEats;
    default:
      return Category.undefined;
  }
}
