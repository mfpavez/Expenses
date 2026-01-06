import 'package:flutter/material.dart';
import 'package:family_app/home_page.dart';
import 'package:family_app/balance_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final GlobalKey<HomePageState> _homePageKey = GlobalKey<HomePageState>();
  final GlobalKey<BalancePageState> _balancePageKey =
      GlobalKey<BalancePageState>();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentPage == 0) {
                _homePageKey.currentState?.fetchCurrentMonthExpenses(refreshCache: true);
              } else if (_currentPage == 1) {
                _balancePageKey.currentState?.fetchExpenses(refresh: true);
              }
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: _currentPage == 0 ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.list_alt,
                color: _currentPage == 0 ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onPressed: () {
              _pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: _currentPage == 1 ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compare_arrows,
                color: _currentPage == 1 ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onPressed: () {
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
          if (page == 1) {
            _balancePageKey.currentState?.animateChart();
          }
        },
        children: [
          HomePage(key: _homePageKey),
          BalancePage(key: _balancePageKey),
        ],
      ),
    );
  }
}
