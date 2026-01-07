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
        return const Color(0xFFC17942); // Lighter Warm Sienna
      case Category.houseBills:
        return const Color(0xFF4A90A4); // Lighter Ocean Blue
      case Category.credito:
        return const Color(0xFF9E749E); // Lighter Mauve
      case Category.contribuciones:
        return const Color(0xFF8B7ABF); // Lighter Indigo
      case Category.education:
        return const Color(0xFF629B6B); // Lighter Natural Green
      case Category.leisure:
        return const Color(0xFFBE6B8B); // Lighter Deep Rose
      case Category.uberEats:
        return const Color(0xFFA48B4A); // Lighter Olive Gold
      case Category.undefined:
      default:
        return const Color(0xFF8E9196); // Lighter Slate
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
    case 'ubereats':
      return Category.uberEats;
    default:
      return Category.undefined;
  }
}
