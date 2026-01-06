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
