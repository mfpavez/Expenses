import 'package:family_app/models/category.dart';
import 'package:flutter/material.dart';
import 'package:family_app/models/expense.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:animations/animations.dart';
import 'package:family_app/category_expenses_page.dart';

class BalancePage extends StatefulWidget {
  const BalancePage({super.key});

  @override
  State<BalancePage> createState() => BalancePageState();
}

class BalancePageState extends State<BalancePage> with AutomaticKeepAliveClientMixin<BalancePage>, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _allTimeExpenses = [];
  Map<Category, double> _categoryBudgets = {};
  bool _isLoading = true;
  String? _error;

  String _currentMonthName = '';
  String _previousMonth1Name = '';
  String _previousMonth2Name = '';
  bool _isDataLoaded = false;
  bool _isAddingPayout = false;

  late AnimationController _chartAnimationController;
  late Animation<double> _chartAnimation;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeOutQuart,
    );

    if (!_isDataLoaded) {
      final now = DateTime.now();
      _currentMonthName = DateFormat('MMMM').format(now);
      _previousMonth1Name = DateFormat('MMMM').format(DateTime(now.year, now.month - 1));
      _previousMonth2Name = DateFormat('MMMM').format(DateTime(now.year, now.month - 2));
      _fetchAllData();
    }
  }

  @override
  void dispose() {
    _chartAnimationController.dispose();
    super.dispose();
  }

  void animateChart() {
    debugPrint('animateChart triggered');
    if (mounted) {
      _chartAnimationController.forward(from: 0.0);
    }
  }

  Future<void> _fetchAllData({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _expenseService.fetchAllExpenses(refreshCache: refresh),
        _expenseService.fetchBudget(refreshCache: refresh),
      ]);

      setState(() {
        _allTimeExpenses = results[0] as List<Expense>;
        _categoryBudgets = results[1] as Map<Category, double>;
        _isDataLoaded = true;
        _isLoading = false;
      });
      animateChart();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> fetchExpenses({bool refresh = false}) async {
    await _fetchAllData(refresh: refresh);
  }

  double _getNonX2ExpensesPaidBy(String person, List<Expense> expenses) {
    return expenses
        .where((e) => e.paidBy == person && !e.isX2)
        .fold(0.0, (sum, e) => sum + e.amount);
  }
  
  double _getTotalX2ExpensesPaidBy(String person, List<Expense> expenses) {
    return expenses
        .where((e) => e.paidBy == person && e.isX2)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, List<Expense>> _groupExpensesByMonth(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};
    for (final expense in expenses) {
      final month = DateFormat('MMMM').format(expense.date);
      if (grouped[month] == null) {
        grouped[month] = [];
      }
      grouped[month]!.add(expense);
    }
    return grouped;
  }

  Map<String, double> _getCategorySummary(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return {};
    }

    final nonX2Expenses = expenses.where((e) => !e.isX2).toList();
    if (nonX2Expenses.isEmpty) {
      return {};
    }

    final Map<Category, double> categoryTotals = {};
    for (var expense in nonX2Expenses) {
      categoryTotals.update(expense.category, (value) => value + expense.amount,
          ifAbsent: () => expense.amount);
    }

    var sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, double> summary = {};
    double othersTotal = 0.0;

    if (sortedCategories.length > 3) {
      for (int i = 0; i < 3; i++) {
        summary[sortedCategories[i].key.name] = sortedCategories[i].value;
      }
      for (int i = 3; i < sortedCategories.length; i++) {
        othersTotal += sortedCategories[i].value;
      }
      if (othersTotal > 0) {
        summary['Others'] = othersTotal;
      }
    } else {
      for (var entry in sortedCategories) {
        summary[entry.key.name] = entry.value;
      }
    }

    return summary;
  }
  
  String _formatAmountToThousands(double amount) {
    if (amount < 1000) {
      return _currencyFormat.format(amount).trim();
    }
    final int thousands = (amount / 1000).round();
    final NumberFormat thousandsFormatter = NumberFormat('#,##0', 'en_US');
    return '${thousandsFormatter.format(thousands)}k';
  }

  double _calculateTotal(List<Expense> expenses) {
    return expenses.where((e) => !e.isX2).fold(0.0, (sum, e) => sum + e.amount);
  }

  List<double> _getLast13MonthsTotals(List<Expense> allExpenses) {
    final now = DateTime.now();
    final List<double> totals = [];
    final nonX2Expenses = allExpenses.where((e) => !e.isX2).toList();

    for (int i = 12; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i);
      final monthExpenses = nonX2Expenses.where((e) =>
          e.date.year == targetDate.year && e.date.month == targetDate.month);
      totals.add(monthExpenses.fold(0.0, (sum, e) => sum + e.amount));
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final groupedExpenses = _groupExpensesByMonth(_allTimeExpenses);
    final currentMonthExpenses = groupedExpenses[_currentMonthName] ?? [];
    final previousMonth1Expenses = groupedExpenses[_previousMonth1Name] ?? [];
    final previousMonth2Expenses = groupedExpenses[_previousMonth2Name] ?? [];
    final last13MonthsTotals = _getLast13MonthsTotals(_allTimeExpenses);

    final List<String> monthLabels = [];
    final now = DateTime.now();
    for (int i = 12; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i);
      monthLabels.add(DateFormat('MMM').format(targetDate)[0]);
    }

    return Scaffold(
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_error'),
                ],
              ),
            )
          : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildUnifiedBalanceCard(_allTimeExpenses),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _isLoading 
                          ? _buildTitlePlaceholder(key: const ValueKey('t1'))
                          : Text(
                              '$_currentMonthName: ${_currencyFormat.format(_calculateTotal(currentMonthExpenses))}',
                              key: const ValueKey('v1'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _isLoading 
                        ? _buildChartPlaceholder(key: const ValueKey('c1'))
                        : _buildCategorySummaryChart(currentMonthExpenses),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _isLoading
                          ? _buildTitlePlaceholder(key: const ValueKey('t2'))
                          : Text(
                              '$_previousMonth1Name: ${_currencyFormat.format(_calculateTotal(previousMonth1Expenses))}',
                              key: const ValueKey('v2'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _isLoading
                        ? _buildChartPlaceholder(key: const ValueKey('c2'))
                        : _buildCategorySummaryChart(previousMonth1Expenses),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: _isLoading
                          ? _buildTitlePlaceholder(key: const ValueKey('t3'))
                          : Text(
                              '$_previousMonth2Name: ${_currencyFormat.format(_calculateTotal(previousMonth2Expenses))}',
                              key: const ValueKey('v3'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _isLoading
                        ? _buildChartPlaceholder(key: const ValueKey('c3'))
                        : _buildCategorySummaryChart(previousMonth2Expenses),
                    ),
                    const SizedBox(height: 40),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Expenses History (Last 13 Months)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _isLoading 
                        ? Center(child: SpinKitPulse(color: Theme.of(context).colorScheme.primary, size: 40))
                        : AnimatedBuilder(
                            animation: _chartAnimation,
                            builder: (context, child) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalMonthlyBudget = _categoryBudgets.values.fold(0.0, (sum, val) => sum + val);

                                  final lineBarsData = [
                                    // Main Expenses Line
                                    LineChartBarData(
                                      spots: last13MonthsTotals
                                          .asMap()
                                          .entries
                                          .map((e) =>
                                              FlSpot(e.key.toDouble(), e.value * _chartAnimation.value))
                                          .toList(),
                                      isCurved: true,
                                      color: Theme.of(context).colorScheme.primary,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      ),
                                    ),
                                    // Budget Reference Line
                                    if (totalMonthlyBudget > 0)
                                      LineChartBarData(
                                        spots: List.generate(
                                          last13MonthsTotals.length,
                                          (i) => FlSpot(i.toDouble(), totalMonthlyBudget * _chartAnimation.value),
                                        ),
                                        dashArray: [5, 5],
                                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                                        barWidth: 2,
                                        dotData: const FlDotData(show: false),
                                      ),
                                  ];

                                  final tooltipsOnBar = [lineBarsData[0]].map((bar) {
                                    return bar.spots.map((spot) {
                                      return ShowingTooltipIndicators([
                                        LineBarSpot(
                                          bar,
                                          0,
                                          spot,
                                        ),
                                      ]);
                                    }).toList();
                                  }).expand((i) => i).toList();

                                  final double rawMaxY = last13MonthsTotals.isEmpty 
                                      ? totalMonthlyBudget 
                                      : [
                                          ...last13MonthsTotals,
                                          totalMonthlyBudget
                                        ].reduce((a, b) => a > b ? a : b);
                                  final double maxY = rawMaxY == 0 ? 1000 : rawMaxY * 1.3;

                                  return LineChart(
                                    LineChartData(
                                      minY: 0,
                                      maxY: maxY,
                                      showingTooltipIndicators: tooltipsOnBar,
                                      gridData: const FlGridData(show: false),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index >= 0 && index < monthLabels.length) {
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 24.0),
                                                  child: Text(
                                                    monthLabels[index],
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.primary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                            interval: 1,
                                            reservedSize: 40,
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      lineBarsData: lineBarsData,
                                      lineTouchData: LineTouchData(
                                        enabled: false,
                                        touchTooltipData: LineTouchTooltipData(
                                          getTooltipColor: (touchedSpot) => Colors.transparent,
                                          tooltipPadding: EdgeInsets.zero,
                                          tooltipMargin: 8,
                                          getTooltipItems: (touchedSpots) {
                                            return touchedSpots.map((LineBarSpot touchedSpot) {
                                              return LineTooltipItem(
                                                _formatAmountToThousands(touchedSpot.y / (_chartAnimation.value > 0 ? _chartAnimation.value : 1)),
                                                TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ),
                                    ),
                                    duration: const Duration(milliseconds: 50),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),

    );
  }

  Widget _buildTitlePlaceholder({Key? key}) {
    return Container(
      key: key,
      height: 20,
      width: 150,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const SpinKitThreeBounce(color: Colors.grey, size: 12),
    );
  }

  Widget _buildChartPlaceholder({Key? key}) {
    return Container(
      key: key,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.zero,
      ),
      child: const Center(
        child: SpinKitThreeBounce(color: Colors.grey, size: 20),
      ),
    );
  }

  Color _getCategoryColor(dynamic category) {
    if (category is Category) {
      return category.color;
    } else if (category is String) {
       // Handle 'Others' or string lookups
       if (category == 'Others') return const Color(0xFF607D8B); // Blue Grey
       try {
         return categoryFromString(category).color;
       } catch (_) {
         return const Color(0xFF9E9E9E);
       }
    }
    return const Color(0xFF9E9E9E);
  }

  Widget _buildCategorySummaryChart(List<Expense> expenses) {
    final nonX2Expenses = expenses.where((e) => !e.isX2).toList();
    final categorySummary = _getCategorySummary(expenses);
    if (categorySummary.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = categorySummary.values.reduce((a, b) => a + b);
    if (total == 0) {
      return const SizedBox.shrink();
    }

    List<Widget> bars = [];
    categorySummary.forEach((categoryName, amount) {
      final percentage = (amount / total) * 100;
      final color = _getCategoryColor(categoryName == 'Others' ? 'Others' : categoryFromString(categoryName));

      bars.add(
        Expanded(
          flex: percentage.toInt(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: OpenContainer<Object>(
                closedElevation: 0,
                closedColor: color,
                openColor: color,
                middleColor: color,
                closedShape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                openElevation: 0,
                transitionDuration: const Duration(milliseconds: 500),
                closedBuilder: (context, action) => Container(
                  color: color,
                  child: Center(
                    child: Text(
                      '$categoryName\n${_formatAmountToThousands(amount)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                openBuilder: (context, action) {
                  List<Expense> filtered;
                  if (categoryName == 'Others') {
                    // Get the top 3 category names to identify which ones are "Others"
                    final Map<Category, double> categoryTotals = {};
                    for (var expense in nonX2Expenses) {
                      categoryTotals.update(
                          expense.category, (value) => value + expense.amount,
                          ifAbsent: () => expense.amount);
                    }
                    var sortedCategories = categoryTotals.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final top3Names = sortedCategories
                        .take(3)
                        .map((e) => e.key.name)
                        .toSet();
                    
                    filtered = nonX2Expenses
                        .where((e) => !top3Names.contains(e.category.name))
                        .toList();
                  } else {
                    filtered = nonX2Expenses
                        .where((e) => e.category.name == categoryName)
                        .toList();
                  }
                  return CategoryExpensesPage(
                    categoryName: categoryName,
                    expenses: filtered,
                    backgroundColor: color,
                    onClose: action,
                  );
                },
                onClosed: (result) {
                  if (result == true) {
                    fetchExpenses(refresh: true);
                  }
                },
              ),
            ),
          ),
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: bars,
          ),
        ),
      ],
    );
  }


  Widget _buildUnifiedBalanceCard(List<Expense> expenses) {
    final double manuelNonX2 = _getNonX2ExpensesPaidBy("Manuel", expenses);
    final double tamaraNonX2 = _getNonX2ExpensesPaidBy("Tamara", expenses);
    final double manuelX2 = _getTotalX2ExpensesPaidBy("Manuel", expenses);
    final double tamaraX2 = _getTotalX2ExpensesPaidBy("Tamara", expenses);

    final double totalPaidByManuel = manuelNonX2 + manuelX2;
    final double totalPaidByTamara = tamaraNonX2 + tamaraX2;

    final double totalAllExpenses = totalPaidByManuel + totalPaidByTamara;
    final double eachPersonShare = totalAllExpenses / 2;

    final double manuelNetBalance = totalPaidByManuel - eachPersonShare;

    String statusText;
    String? amountText;
    String? debtor;
    String? creditor;
    double amountOwed = manuelNetBalance.abs();

    if (manuelNetBalance > 0) {
      debtor = 'Tamara';
      creditor = 'Manuel';
      statusText = 'Tamara owes Manuel';
      amountText = _currencyFormat.format(amountOwed);
    } else if (manuelNetBalance < 0) {
      debtor = 'Manuel';
      creditor = 'Tamara';
      statusText = 'Manuel owes Tamara';
      amountText = _currencyFormat.format(amountOwed);
    } else {
      statusText = 'Balances are even!';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      elevation: 2,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Text(
                'Family Balance Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Row(
                  key: ValueKey(_isLoading),
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _isLoading 
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: SpinKitDoubleBounce(color: Colors.indigo, size: 28),
                        )
                      : Text(
                          amountText ?? 'Even',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                    if (debtor != null || _isLoading) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: (_isAddingPayout || _isLoading)
                            ? null
                            : () => _handlePayout(debtor!, creditor!, amountOwed),
                        icon: (_isAddingPayout || _isLoading)
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: SpinKitSpinningLines(
                                    color: Theme.of(context).colorScheme.primary, size: 16))
                            : const Icon(Icons.compare_arrows, size: 16),
                        label: const Text('REGISTER PAYOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 4,
                          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              _isLoading
                ? const SizedBox(height: 14)
                : Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayout(
      String debtor, String creditor, double amount) async {
    final double payoutAmount = amount * 2;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Text(
          'Has $debtor deposited ${_currencyFormat.format(amount)} to $creditor?\n\n'
          'This will add an "X2" expense of ${_currencyFormat.format(payoutAmount)} paid by $debtor to reset the balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isAddingPayout = true);
    try {
      await _expenseService.addExpense(
        'PAYOUT BALANCE X2',
        debtor,
        payoutAmount,
        DateTime.now(),
        'PAYOUT',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout registered successfully!')),
      );
      fetchExpenses(refresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register payout: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingPayout = false);
      }
    }
  }
}

class _AnimatedNumber extends StatelessWidget {
  final double value;
  final String Function(num) formatter;
  final TextStyle style;

  const _AnimatedNumber({
    required this.value,
    required this.formatter,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 2400),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        return Text(
          formatter(val),
          style: style,
        );
      },
    );
  }
}