import 'package:family_app/category_expenses_page.dart';
import 'package:family_app/models/expense.dart';
import 'package:family_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:family_app/main_screen.dart';

void main() {
  runApp(const MyApp());
}

// GoRouter configuration
final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/category-details',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final categoryName = extra['categoryName'] as String;
        final expenses = extra['expenses'] as List<Expense>;
        final backgroundColor = extra['backgroundColor'] as Color? ?? Colors.white;
        return CategoryExpensesPage(
          categoryName: categoryName,
          expenses: expenses,
          backgroundColor: backgroundColor,
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: ThemeService().seedColor,
      builder: (context, currentSeed, _) {
        return MaterialApp.router(
          title: 'Expenses',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: currentSeed,
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: const TextTheme(
              titleLarge: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              bodyMedium: TextStyle(fontSize: 12.0),
              labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
            ),
          ),
          routerConfig: _router,
        );
      },
    );
  }
}
