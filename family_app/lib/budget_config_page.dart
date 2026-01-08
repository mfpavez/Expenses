import 'package:flutter/material.dart';
import 'package:family_app/models/expense.dart';
import 'package:family_app/models/category.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:family_app/utils/month_utils.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class BudgetConfigPage extends StatefulWidget {
  const BudgetConfigPage({super.key});

  @override
  State<BudgetConfigPage> createState() => BudgetConfigPageState();
}

class BudgetConfigPageState extends State<BudgetConfigPage>
    with AutomaticKeepAliveClientMixin<BudgetConfigPage> {
  @override
  bool get wantKeepAlive => true;

  final ExpenseService _expenseService = ExpenseService();
  final Map<Category, TextEditingController> _controllers = {};
  double _totalBudget = 0.0;
  bool _isLoading = true;
  bool _isSaving = false;

  List<Expense> _allExpenses = [];
  double _yearlySavings = 0.0;
  double _yearlyBudget = 0.0;
  double _monthlySavings = 0.0;
  bool _isExpensesLoaded = false;

  String _selectedMonth = '';
  final ScrollController _scrollController = ScrollController();

  final List<String> _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = MonthUtils.getSpanishMonth(now);
    _initializeControllers();
    loadBudgetData();

    // Scroll to selected month after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMonth(now.month - 1);
    });
  }

  void _scrollToMonth(int index) {
    if (_scrollController.hasClients) {
      double offset = (index - 1) * 90.0;
      if (offset < 0) offset = 0;
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _initializeControllers() {
    final sortedCategories = List<Category>.from(Category.values);
    sortedCategories.sort((a, b) {
      if (a == Category.undefined) return 1;
      if (b == Category.undefined) return -1;
      return a.name.compareTo(b.name);
    });

    _controllers.clear();
    for (var category in sortedCategories) {
      final controller = TextEditingController(text: '0');
      controller.addListener(_calculateTotal);
      _controllers[category] = controller;
    }
  }

  Future<void> loadBudgetData({bool refreshCache = false}) async {
    setState(() => _isLoading = true);
    _controllers.forEach((_, controller) => controller.text = '0');

    try {
      if (refreshCache || !_isExpensesLoaded) {
        _allExpenses =
            await _expenseService.fetchAllExpenses(refreshCache: refreshCache);
        _isExpensesLoaded = true;
      }

      final budget = await _expenseService.fetchBudget(_selectedMonth,
          refreshCache: refreshCache);
      budget.forEach((category, amount) {
        if (_controllers.containsKey(category)) {
          _controllers[category]!.text = amount.toStringAsFixed(0);
        }
      });
      _calculateTotal();
      await _calculateSavings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load budget: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateSavings() async {
    const int targetYear = 2026;
    
    // Calculate Monthly Savings (Current Selection)
    final currentMonthExpenses = _allExpenses.where((e) {
      // Filter expenses by selected month AND year 2026
      final expenseMonth = MonthUtils.getSpanishMonth(e.date);
      return e.date.year == targetYear && 
             expenseMonth == _selectedMonth && 
             !e.item.toUpperCase().endsWith('X2');
    }).fold(0.0, (sum, e) => sum + e.amount);

    _monthlySavings = _totalBudget - currentMonthExpenses;

    // Calculate Yearly Savings (YTD for 2026)
    double yearlySavings = 0.0;
    double yearlyBudget = 0.0;
    final now = DateTime.now();
    
    // Determine how many months to calculate for YTD.
    // If we are in 2026, go up to previous month.
    // If we are past 2026, calculate full year.
    // If we are before 2026, calculation is 0.
    int monthsToCalculate = 0;
    if (now.year == targetYear) {
      monthsToCalculate = now.month - 1;
    } else if (now.year > targetYear) {
      monthsToCalculate = 12;
    }

    for (int i = 0; i < monthsToCalculate; i++) {
      final monthName = _months[i];
      
      // Get total budget for that month
      // Assuming budget webhook returns data valid for this year context
      final budgetMap = await _expenseService.fetchBudget(monthName);
      final totalBudget = budgetMap.values.fold(0.0, (sum, val) => sum + val);
      yearlyBudget += totalBudget;

      // Get total expenses for that month in 2026
      final totalExpenses = _allExpenses.where((e) {
        final expenseMonth = MonthUtils.getSpanishMonth(e.date);
        return e.date.year == targetYear &&
               expenseMonth == monthName && 
               !e.item.toUpperCase().endsWith('X2');
      }).fold(0.0, (sum, e) => sum + e.amount);

      yearlySavings += (totalBudget - totalExpenses);
    }

    if (mounted) {
      setState(() {
        _yearlySavings = yearlySavings;
        _yearlyBudget = yearlyBudget;
      });
    }
  }

  Future<void> _saveBudget() async {
    setState(() => _isSaving = true);
    try {
      final Map<Category, double> budgetToSave = {};
      _controllers.forEach((category, controller) {
        final val = double.tryParse(controller.text) ?? 0.0;
        budgetToSave[category] = val;
      });

      await _expenseService.updateBudget(budgetToSave, _selectedMonth);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Budget configuration saved successfully!')),
        );
        loadBudgetData(refreshCache: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save budget: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _calculateTotal() {
    double sum = 0;
    _controllers.forEach((category, controller) {
      sum += double.tryParse(controller.text) ?? 0.0;
    });
    if (mounted) {
      setState(() {
        _totalBudget = sum;
      });
      _calculateSavings();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _isLoading
          ? Center(
              child: SpinKitRotatingPlain(
                  color: Theme.of(context).colorScheme.primary, size: 50.0))
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // YEARLY SECTION
                    Container(
                      margin: const EdgeInsets.all(12.0),
                      padding: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'ANNUAL PERFORMANCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Card(
                                  margin:
                                      const EdgeInsets.only(left: 12, right: 4),
                                  elevation: 0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.5),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Column(
                                      children: [
                                                                              Text(
                                                                                'Budget (YTD)',
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: Theme.of(context)
                                                                                      .colorScheme
                                                                                      .onPrimaryContainer,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 4),
                                                                              Text(
                                                                                _currencyFormat.format(_yearlyBudget),
                                                                                style: TextStyle(
                                                                                  fontSize: 22,
                                                                                  fontWeight: FontWeight.w900,
                                                                                  color: Theme.of(context)
                                                                                      .colorScheme
                                                                                      .primary,
                                                                                ),
                                                                              ),                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  margin:
                                      const EdgeInsets.only(left: 4, right: 12),
                                  elevation: 0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.5),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16.0),
                                    child: Column(
                                      children: [
                                                                              Text(
                                                                                'Savings (YTD)',
                                                                                style: TextStyle(
                                                                                  fontSize: 12,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: Theme.of(context)
                                                                                      .colorScheme
                                                                                      .onPrimaryContainer,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(height: 4),
                                                                              Text(
                                                                                _currencyFormat
                                                                                    .format(_yearlySavings),
                                                                                style: TextStyle(
                                                                                  fontSize: 22,
                                                                                  fontWeight: FontWeight.w900,
                                                                                  color: _yearlySavings >= 0
                                                                                      ? Colors.green[700]
                                                                                      : Colors.red[700],
                                                                                ),
                                                                              ),                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // MONTHLY SECTION
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      padding: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'MONTHLY DETAILS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 50,
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white,
                                    Colors.white,
                                    Colors.white.withOpacity(0.0),
                                  ],
                                  stops: const [0.0, 0.05, 0.95, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                scrollDirection: Axis.horizontal,
                                itemCount: _months.length,
                                itemBuilder: (context, index) {
                                  final month = _months[index];
                                  final isSelected = month == _selectedMonth;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4.0, vertical: 8.0),
                                    child: ChoiceChip(
                                      label: Text(month),
                                      selected: isSelected,
                                      onSelected: (bool selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedMonth = month;
                                          });
                                          loadBudgetData();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    elevation: 0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Budget',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _currencyFormat
                                                .format(_totalBudget),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Card(
                                    elevation: 0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Expenses',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _currencyFormat.format(
                                                _totalBudget - _monthlySavings),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Card(
                                    elevation: 0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Remaining',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _currencyFormat
                                                .format(_monthlySavings),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: _monthlySavings >= 0
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'CATEGORIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Expenses / Budget',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            itemCount: _controllers.length,
                            itemBuilder: (context, index) {
                              final category =
                                  _controllers.keys.elementAt(index);
                              final controller = _controllers[category]!;
                              final budgetValue = double.tryParse(controller.text) ?? 0.0;

                              final spent = _allExpenses.where((e) {
                                final expenseMonth = MonthUtils.getSpanishMonth(e.date);
                                return e.category == category &&
                                       e.date.year == 2026 &&
                                       expenseMonth == _selectedMonth &&
                                       !e.item.toUpperCase().endsWith('X2');
                              }).fold(0.0, (sum, e) => sum + e.amount);

                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withOpacity(0.5),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: category.color,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          category.name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () =>
                                              _showEditBudgetDialog(category),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                '\$ ${_currencyFormat.format(spent)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: spent > budgetValue && budgetValue > 0
                                                      ? Colors.red[700]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                ' / ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[400],
                                                ),
                                              ),
                                              Text(
                                                '\$ ${_currencyFormat.format(budgetValue)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSecondaryContainer,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final bool? confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Budget Update'),
                                    content: Text(
                                        'Are you sure you want to update the monthly budget to ${_currencyFormat.format(_totalBudget)}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  _saveBudget();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: _isSaving
                            ? const SpinKitThreeBounce(
                                color: Colors.white, size: 20)
                            : const Text('UPDATE BUDGET',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showEditBudgetDialog(Category category) async {
    final controller = _controllers[category]!;
    final TextEditingController editController =
        TextEditingController(text: controller.text);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Budget for ${category.name}'),
          content: TextField(
            controller: editController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Budget Amount',
              prefixText: '\$ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newValue = double.tryParse(editController.text) ?? 0.0;
                controller.text = newValue.toStringAsFixed(0);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }
}