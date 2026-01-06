import 'dart:ui' as ui;
import 'package:family_app/models/category.dart';
import 'package:flutter/material.dart';
import 'package:family_app/models/expense.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class BalancePage extends StatefulWidget {
  const BalancePage({super.key});

  @override
  State<BalancePage> createState() => BalancePageState();
}

class BalancePageState extends State<BalancePage> with AutomaticKeepAliveClientMixin<BalancePage> {
  @override
  bool get wantKeepAlive => true;

  final ExpenseService _expenseService = ExpenseService();
  List<Expense> _allTimeExpenses = [];
  bool _isLoading = true;
  String? _error;

  String _currentMonthName = '';
  String _previousMonth1Name = '';
  String _previousMonth2Name = '';
  bool _isDataLoaded = false;
  bool _isAddingPayout = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: 'CLP',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    if (!_isDataLoaded) {
      final now = DateTime.now();
      _currentMonthName = DateFormat('MMMM').format(now);
      _previousMonth1Name = DateFormat('MMMM').format(DateTime(now.year, now.month - 1));
      _previousMonth2Name = DateFormat('MMMM').format(DateTime(now.year, now.month - 2));
      _fetchAllData();
    }
  }

  Future<void> _fetchAllData({bool refresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allExpenses = await _expenseService.fetchAllExpenses(refreshCache: refresh);
      setState(() {
        _allTimeExpenses = allExpenses;
        _isDataLoaded = true;
        _isLoading = false;
      });
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
      return _currencyFormat.format(amount);
    }
    final int thousands = (amount / 1000).round();
    final NumberFormat thousandsFormatter = NumberFormat('#,##0', 'en_US');
    return 'CLP ${thousandsFormatter.format(thousands)}k';
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
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
                        const Text(
                          'Family Balance Overview',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        _buildTotalBalanceCard(_allTimeExpenses, 'Total Balance'),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            '$_currentMonthName: ${_currencyFormat.format(_calculateTotal(currentMonthExpenses))}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildCategorySummaryChart(currentMonthExpenses),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            '$_previousMonth1Name: ${_currencyFormat.format(_calculateTotal(previousMonth1Expenses))}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildCategorySummaryChart(previousMonth1Expenses),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            '$_previousMonth2Name: ${_currencyFormat.format(_calculateTotal(previousMonth2Expenses))}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildCategorySummaryChart(previousMonth2Expenses),
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
                          height: 150,
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: CustomPaint(
                            painter: LineChartPainter(
                              data: last13MonthsTotals,
                              monthLabels: monthLabels,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),

    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'supermarket':
        return Colors.pink[200]!;
      case 'house bills':
        return Colors.blue[200]!;
      case 'credito':
        return Colors.green[200]!;
      case 'contribuciones':
        return Colors.orange[200]!;
      case 'education':
        return Colors.purple[200]!;
      case 'others':
        return Colors.blueGrey[300]!;
      default:
        return Colors.grey[400]!;
    }
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
    categorySummary.forEach((category, amount) {
      final percentage = (amount / total) * 100;
      bars.add(
        Expanded(
          flex: percentage.toInt(),
          child: GestureDetector(
            onTap: () async {
              List<Expense> filtered;
              if (category == 'Others') {
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
                    .where((e) => e.category.name == category)
                    .toList();
              }
              final result = await context.push('/category-details', extra: {
                'categoryName': category,
                'expenses': filtered,
              });
              if (result == true) {
                fetchExpenses(refresh: true);
              }
            },
            child: Container(
              color: _getCategoryColor(category),
              child: Center(
                child: Text(
                  '$category\n${_formatAmountToThousands(amount)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Row(
              children: bars,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildTotalBalanceCard(List<Expense> expenses, String title) {
    return _buildDifferenceOwedCard(expenses, '');
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

  Widget _buildDifferenceOwedCard(List<Expense> expenses, String title) {
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
    Color messageColor;
    String? debtor;
    String? creditor;
    double amountOwed = manuelNetBalance.abs();

    if (manuelNetBalance > 0) {
      debtor = 'Tamara';
      creditor = 'Manuel';
      statusText = 'Tamara owes Manuel';
      amountText = _currencyFormat.format(amountOwed);
      messageColor = Colors.grey[700]!;
    } else if (manuelNetBalance < 0) {
      debtor = 'Manuel';
      creditor = 'Tamara';
      statusText = 'Manuel owes Tamara';
      amountText = _currencyFormat.format(amountOwed);
      messageColor = Colors.grey[700]!;
    } else {
      statusText = 'Balances are even!';
      messageColor = Colors.grey[700]!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: messageColor,
                      ),
                    ),
                    if (amountText != null)
                      Text(
                        amountText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: messageColor,
                        ),
                      ),
                  ],
                ),
                if (debtor != null) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isAddingPayout
                        ? null
                        : () => _handlePayout(debtor!, creditor!, amountOwed),
                    icon: _isAddingPayout
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.compare_arrows, size: 18),
                    label: const Text('Register Payout', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[50],
                      foregroundColor: Colors.blueGrey[800],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> monthLabels;
  final Color color;

  LineChartPainter({
    required this.data,
    required this.monthLabels,
    required this.color,
  });

  String _formatValue(double value) {
    if (value == 0) return '0';
    final formatter = NumberFormat('#,###', 'es_CL');
    if (value < 1000) return formatter.format(value);
    return '${formatter.format((value / 1000).round())}k';
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Add vertical padding for labels
    const double topPadding = 20.0;
    const double bottomPadding = 30.0; // Increased for month labels
    final double chartHeight = size.height - topPadding - bottomPadding;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    double maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1.0;

    final double widthInterval = size.width / (data.length - 1);
    
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      double x = i * widthInterval;
      double y = topPadding + (chartHeight - (data[i] / maxVal * chartHeight));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - bottomPadding + 10);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      if (i == data.length - 1) {
        fillPath.lineTo(x, size.height - bottomPadding + 10);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw points and labels
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      double x = i * widthInterval;
      double y = topPadding + (chartHeight - (data[i] / maxVal * chartHeight));
      
      // Draw dot
      canvas.drawCircle(Offset(x, y), 3.0, pointPaint);

      // Draw value label
      final valuePainter = TextPainter(
        text: TextSpan(
          text: _formatValue(data[i]),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      valuePainter.layout();
      
      valuePainter.paint(
        canvas,
        Offset(x - (valuePainter.width / 2), y - valuePainter.height - 4),
      );

      // Draw month label
      if (i < monthLabels.length) {
        final monthPainter = TextPainter(
          text: TextSpan(
            text: monthLabels[i],
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        monthPainter.layout();
        monthPainter.paint(
          canvas,
          Offset(x - (monthPainter.width / 2), size.height - 15),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}