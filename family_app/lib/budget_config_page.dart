import 'package:flutter/material.dart';
import 'package:family_app/models/category.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class BudgetConfigPage extends StatefulWidget {
  const BudgetConfigPage({super.key});

  @override
  State<BudgetConfigPage> createState() => BudgetConfigPageState();
}

class BudgetConfigPageState extends State<BudgetConfigPage> with AutomaticKeepAliveClientMixin<BudgetConfigPage> {
  @override
  bool get wantKeepAlive => true;

  final ExpenseService _expenseService = ExpenseService();
  final Map<Category, TextEditingController> _controllers = {};
  double _totalBudget = 0.0;
  bool _isLoading = true;
  bool _isSaving = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    loadBudgetData();
  }

  void _initializeControllers() {
    for (var category in Category.values) {
      if (category == Category.undefined) continue;
      final controller = TextEditingController(text: '0');
      controller.addListener(_calculateTotal);
      _controllers[category] = controller;
    }
  }

  Future<void> loadBudgetData({bool refreshCache = false}) async {
    setState(() => _isLoading = true);
    try {
      final budget = await _expenseService.fetchBudget(refreshCache: refreshCache);
      budget.forEach((category, amount) {
        if (_controllers.containsKey(category)) {
          _controllers[category]!.text = amount.toStringAsFixed(0);
        }
      });
      _calculateTotal();
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

  Future<void> _saveBudget() async {
    setState(() => _isSaving = true);
    try {
      final Map<Category, double> budgetToSave = {};
      _controllers.forEach((category, controller) {
        final val = double.tryParse(controller.text) ?? 0.0;
        budgetToSave[category] = val;
        debugPrint('Preparing to save $category: $val');
      });

      await _expenseService.updateBudget(budgetToSave);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget configuration saved successfully!')),
        );
        // Refresh cache after save
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
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _isLoading
          ? Center(child: SpinKitRotatingPlain(color: Theme.of(context).colorScheme.primary, size: 50.0))
          : Column(
              children: [
                // Total Budget Summary Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 2,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Total Monthly Budget',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(_totalBudget),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Configure Category Budgets',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _controllers.length,
                    itemBuilder: (context, index) {
                      final category = _controllers.keys.elementAt(index);
                      final controller = _controllers[category]!;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        elevation: 0,
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: category.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  category.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    prefixText: '\$ ',
                                    hintText: '0',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      final bool? confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Budget Update'),
                          content: Text('Are you sure you want to update the monthly budget to ${_currencyFormat.format(_totalBudget)}?'),
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

                      if (confirmed == true) {
                        _saveBudget();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                        : const Text('UPDATE BUDGET', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
    );
  }
}
