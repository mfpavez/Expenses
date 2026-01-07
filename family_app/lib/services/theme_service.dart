import 'package:flutter/material.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<Color> seedColor = ValueNotifier<Color>(const Color(0xFF3F51B5));

  static const List<Map<String, dynamic>> financialSeeds = [
    {'name': 'Premium Purple', 'color': Color(0xFF7F67BE)},
    {'name': 'Trust Blue', 'color': Color(0xFF1976D2)},
    {'name': 'Growth Green', 'color': Color(0xFF2E7D32)},
    {'name': 'Modern Teal', 'color': Color(0xFF00796B)},
    {'name': 'Fintech Indigo', 'color': Color(0xFF3F51B5)},
    {'name': 'Gold Wealth', 'color': Color(0xFFC49000)},
    {'name': 'Vibrant Orange', 'color': Color(0xFFE64A19)},
  ];

  void updateSeedColor(Color color) {
    seedColor.value = color;
  }
}
