import 'package:family_app/models/category.dart';
import 'package:flutter/material.dart';
import 'package:family_app/models/expense.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin<HomePage> {
  @override
  bool get wantKeepAlive => true;

  static final ExpenseService _expenseService = ExpenseService();
  static List<Expense> _expenses = [];
  static bool _isLoading = true;
  static String? _errorMessage;
  static String _currentMonth = '';
  static bool _isDataLoaded = false;
  Category? _selectedFilterCategory;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: 'CLP',
    decimalDigits: 0,
  );

  final GlobalKey<FormState> _addExpenseFormKey = GlobalKey<FormState>();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedPaidBy = 'Manuel';
  DateTime _selectedDate = DateTime.now();
  Category _selectedCategory = Category.undefined;



  // For highlighting newly added expense
  String? _lastAddedExpenseItem;
  DateTime? _lastAddedExpenseDate;
  late AnimationController _highlightAnimationController;
  late Animation<Color?> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    if (!_isDataLoaded) {
      _currentMonth = DateFormat('MMMM').format(DateTime.now());
      fetchCurrentMonthExpenses(refreshCache: false);
    }
    _highlightAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _highlightAnimation =
        ColorTween(begin: Colors.transparent, end: Colors.yellow[100]).animate(
          CurvedAnimation(
            parent: _highlightAnimationController,
            curve: Curves.easeIn,
          ),
        );
    _highlightAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _lastAddedExpenseItem = null;
          _lastAddedExpenseDate = null;
        });
        _highlightAnimationController.reset();
      }
    });
  }

  bool _isX2Expense(Expense expense) {
    return expense.item.toUpperCase().endsWith('X2');
  }

  List<Expense> _getNonX2Expenses() {
    return _expenses.where((expense) => !_isX2Expense(expense)).toList();
  }

  double _getTotalNonX2Expenses() {
    return _getNonX2Expenses().fold(0.0, (sum, item) => sum + item.amount);
  }

  double _getNonX2ExpensesPaidBy(String person) {
    return _getNonX2Expenses()
        .where((expense) => expense.paidBy.toLowerCase() == person.toLowerCase())
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double _getTotalX2ExpensesPaidBy(String person) {
    return _expenses
        .where((expense) =>
            _isX2Expense(expense) &&
            expense.paidBy.toLowerCase() == person.toLowerCase())
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> fetchCurrentMonthExpenses({bool refreshCache = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fetchedExpenses = await _expenseService.fetchExpenses(_currentMonth, refreshCache: refreshCache);
      setState(() {
        _expenses = fetchedExpenses;
        _isDataLoaded = true;
        _expenses.sort((a, b) {
          final bool aIsDefaultDate = a.date.year == 2020;
          final bool bIsDefaultDate = b.date.year == 2020;

          if (aIsDefaultDate && !bIsDefaultDate) {
            return -1; 
          } else if (!aIsDefaultDate && bIsDefaultDate) {
            return 1; 
          } else {
            return b.date.compareTo(a.date);
          }
        });
      });
    } catch (e) {
      setState(() {
        if (e is Exception) {
          _errorMessage = 'Failed to load expenses: ${e.toString()}';
        } else {
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double get _totalExpensesDisplay => _getTotalNonX2Expenses();

  double _getExpensesPaidByDisplay(String person) =>
      _getNonX2ExpensesPaidBy(person);

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _highlightAnimationController.dispose(); 
    super.dispose();
  }

  Future<void> _showEditExpenseDialog(Expense expense) async {
    Category selectedCategory = expense.category;
    DateTime selectedDate = expense.date;
    String? selectedPaidBy = expense.paidBy;
    final TextEditingController editAmountController =
        TextEditingController(text: expense.amount.toStringAsFixed(0));
    bool isUpdating = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Edit "${expense.item.toUpperCase()}"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: editAmountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Text('Paid By:', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'Manuel',
                          label: Text('Manuel'),
                        ),
                        ButtonSegment<String>(
                          value: 'Tamara',
                          label: Text('Tamara'),
                        ),
                      ],
                      selected: {selectedPaidBy ?? 'Manuel'},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          selectedPaidBy = newSelection.first;
                        });
                      },
                      emptySelectionAllowed: false,
                      multiSelectionEnabled: false,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Category>(
                      value: selectedCategory,
                      items: Category.values.map((Category category) {
                        return DropdownMenuItem<Category>(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (Category? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Date: ${selectedDate.year == 2020 ? "Missing" : DateFormat('MM/dd/yy').format(selectedDate)}',
                        style: TextStyle(
                          color: selectedDate.year == 2020 ? Colors.red : null,
                          fontWeight: selectedDate.year == 2020
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate.year == 2020
                              ? DateTime.now()
                              : selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          final double? newAmount =
                              double.tryParse(editAmountController.text);
                          if (newAmount == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter a valid amount')),
                            );
                            return;
                          }

                          setState(() {
                            isUpdating = true;
                          });
                          try {
                            if (expense.rowNumber == null) {
                              throw Exception('Missing row number.');
                            }

                            await _expenseService.updateExpense(
                              rowNumber: expense.rowNumber!,
                              item: expense.item,
                              category: selectedCategory,
                              date: selectedDate,
                              amount: newAmount,
                              paidBy: selectedPaidBy!,
                            );

                            fetchCurrentMonthExpenses(refreshCache: true);
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Expense updated successfully!')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                isUpdating = false;
                              });
                            }
                          }
                        },
                  child: isUpdating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddExpenseDialog(BuildContext context) async {
    _itemController.clear();
    _amountController.clear();
    _selectedPaidBy = 'Manuel';
    _selectedDate = DateTime.now(); 
    bool isAddingExpense = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Add New Expense'),
              content: Form(
                key: _addExpenseFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _itemController,
                        decoration: const InputDecoration(labelText: 'Item'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an item';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: 'Amount'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const Text('Paid By:', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'Manuel',
                            label: Text('Manuel'),
                          ),
                          ButtonSegment<String>(
                            value: 'Tamara',
                            label: Text('Tamara'),
                          ),
                        ],
                        selected: {_selectedPaidBy ?? 'Manuel'},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedPaidBy = newSelection.first;
                            _addExpenseFormKey.currentState!
                                .validate(); 
                          });
                        },
                        emptySelectionAllowed: false,
                        multiSelectionEnabled: false,
                      ),
                      if (_selectedPaidBy == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Please select who paid',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      DropdownButtonFormField<Category>(
                        value: _selectedCategory,
                        items: Category.values.map((Category category) {
                          return DropdownMenuItem<Category>(
                            value: category,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: (Category? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Date: ${DateFormat('MM/dd/yy').format(_selectedDate)}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAddingExpense
                      ? null
                      : () async {
                          if (_addExpenseFormKey.currentState!.validate()) {
                            setState(() {
                              isAddingExpense = true;
                            });
                            try {
                              await _expenseService.addExpense(
                                _itemController.text,
                                _selectedPaidBy!,
                                double.parse(_amountController.text),
                                _selectedDate,
                                _selectedCategory.name,
                              );

                              fetchCurrentMonthExpenses(refreshCache: true);
                              
                              // Set for highlighting
                              _lastAddedExpenseItem = _itemController.text;
                              _lastAddedExpenseDate = _selectedDate;
                              _highlightAnimationController.forward(from: 0.0);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Expense added successfully!'),
                                ),
                              );
                              Navigator.of(context)
                                  .pop(); 
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to add expense: $e')),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isAddingExpense = false;
                                });
                              }
                            }
                          }
                        },
                  child: isAddingExpense
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    List<DropdownMenuItem<Category?>> items = [
      DropdownMenuItem<Category?>(
        value: null,
        child: const Text("All Categories"),
      ),
    ];

    items.addAll(Category.values.map((category) {
      return DropdownMenuItem<Category?>(
        value: category,
        child: Text(category.name),
      );
    }).toList());

    return Row(
      children: [
        const Icon(Icons.filter_list), // Filter icon
        const SizedBox(width: 8), // Spacing
        DropdownButton<Category?>(
          value: _selectedFilterCategory,
          hint: const Text("Filter by Category"),
          onChanged: (Category? newValue) {
            setState(() {
              _selectedFilterCategory = newValue;
            });
          },
          items: items,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final nonX2Expenses = _getNonX2Expenses();
    final filteredExpenses = _selectedFilterCategory == null
        ? nonX2Expenses
        : nonX2Expenses.where((exp) => exp.category == _selectedFilterCategory).toList();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_errorMessage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            )
          : Column(
              children: [
                _buildSummaryCards(),
                _buildCategorySummaryChart(nonX2Expenses),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Expenses',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      _buildCategoryFilter(),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredExpenses.isEmpty
                      ? const Center(
                          child: Text('No expenses found for this selection.'),
                        )
                      : ListView.builder(
                          itemCount: filteredExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = filteredExpenses[index];
                            final bool isNewlyAdded =
                                _lastAddedExpenseItem == expense.item &&
                                _lastAddedExpenseDate?.day ==
                                    expense.date.day &&
                                _lastAddedExpenseDate?.month ==
                                    expense.date.month &&
                                _lastAddedExpenseDate?.year ==
                                    expense.date.year;

                            Widget expenseCard = Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              elevation:
                                  2.0,
                              color: expense.date.year == 2020
                                  ? Colors.red[100]
                                  : null,
                              shape: expense.date.year == 2020
                                  ? RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        width: 1.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    )
                                  : null,
                              child: ListTile(
                                onLongPress: expense.rowNumber == null
                                    ? null
                                    : () async {
                                        final bool? shouldDelete =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title:
                                                  const Text('Confirm Deletion'),
                                              content: Text(
                                                  'Are you sure you want to delete "${expense.item}"?'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (shouldDelete == true) {
                                          try {
                                            await _expenseService
                                                .removeExpense(
                                                    expense.rowNumber!);
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Expense "${expense.item}" removed.')),
                                            );
                                            fetchCurrentMonthExpenses(refreshCache: true);
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Failed to remove expense: $e')),
                                            );
                                          }
                                        }
                                      },
                                onTap: () => _showEditExpenseDialog(expense),
                                leading: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.blueGrey.withOpacity(0.5),
                                  child: Text(
                                    expense.paidBy[0],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(expense.item.toUpperCase()),
                                subtitle: Text(
                                  expense.date.year == 2020
                                      ? 'Date Missing - Tap to Add'
                                      : '${DateFormat('MM/dd/yy').format(expense.date)} - Paid by ${expense.paidBy}',
                                  style: expense.date.year == 2020
                                      ? const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        )
                                      : null,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat.format(expense.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      expense.category.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _getCategoryColor(expense.category.name),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (isNewlyAdded) {
                              return AnimatedBuilder(
                                animation: _highlightAnimation,
                                builder: (context, child) {
                                  return Container(
                                    color: _highlightAnimation.value,
                                    child: child,
                                  );
                                },
                                child: expenseCard,
                              );
                            } else {
                              return expenseCard;
                            }
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),

    );
  }

  Map<String, double> _getCategorySummary(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return {};
    }

    final Map<Category, double> categoryTotals = {};
    for (var expense in expenses) {
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
                for (var expense in expenses) {
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
                
                filtered = expenses
                    .where((e) => !top3Names.contains(e.category.name))
                    .toList();
              } else {
                filtered = expenses
                    .where((e) => e.category.name == category)
                    .toList();
              }
              final result = await context.push('/category-details', extra: {
                'categoryName': category,
                'expenses': filtered,
              });
              if (result == true) {
                fetchCurrentMonthExpenses(refreshCache: true);
              }
            },
            child: Container(
              color: _getCategoryColor(category),
              child: Center(
                child: Text(
                  '${category}\n${_formatAmountToThousands(amount)}',
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Category Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
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

  String _formatAmountToThousands(double amount) {
    if (amount < 1000) {
      return _currencyFormat.format(amount);
    }
    final int thousands = (amount / 1000).round();
    final NumberFormat thousandsFormatter = NumberFormat('#,##0', 'en_US');
    return 'CLP ${thousandsFormatter.format(thousands)}k';
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Column(
                  children: [
                    const Text(
                      'Total Expenses This Month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(_totalExpensesDisplay),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        const Text(
                          'Paid by Manuel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(_getExpensesPaidByDisplay("Manuel")),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        const Text(
                          'Paid by Tamara',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currencyFormat.format(_getExpensesPaidByDisplay("Tamara")),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
