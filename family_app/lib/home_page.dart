import 'package:family_app/models/category.dart';
import 'package:flutter/material.dart';
import 'package:family_app/models/expense.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:animations/animations.dart';
import 'package:family_app/category_expenses_page.dart';
import 'package:family_app/add_expense_page.dart';

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
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    if (!_isDataLoaded) {
      _currentMonth = DateFormat('MMMM').format(DateTime.now());
      fetchCurrentMonthExpenses(refreshCache: false);
    }
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
                          child: SpinKitSpinningLines(
                            color: Colors.white,
                            size: 20,
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
          ? Center(child: SpinKitRotatingPlain(color: Theme.of(context).colorScheme.primary, size: 50.0))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_errorMessage',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
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

                            Widget expenseCard = Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              elevation:
                                  2.0,
                              color: expense.date.year == 2020
                                  ? Theme.of(context).colorScheme.errorContainer
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
                              child: Slidable(
                                startActionPane: ActionPane(
                                  motion: const ScrollMotion(),
                                  children: [
                                    SlidableAction(
                                      onPressed: (context) => _showEditExpenseDialog(expense),
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      icon: Icons.edit,
                                      label: 'Edit',
                                    ),
                                  ],
                                ),
                                endActionPane: ActionPane(
                                  motion: const ScrollMotion(),
                                  children: [
                                    if (expense.rowNumber != null)
                                      SlidableAction(
                                        onPressed: (actionContext) async {
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
                                            // Show loading dialog
                                            if (!mounted) return;
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  content: Row(
                                                    children: [
                                                      SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: SpinKitSpinningLines(
                                                          color: Theme.of(context).colorScheme.primary,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 20),
                                                      const Text('Deleting...'),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );

                                            try {
                                              await _expenseService
                                                  .removeExpense(
                                                      expense.rowNumber!);
                                              
                                              if (!mounted) return;
                                              Navigator.of(context).pop(); // Close loading dialog

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Expense "${expense.item}" removed.')),
                                              );
                                              fetchCurrentMonthExpenses(refreshCache: true);
                                            } catch (e) {
                                              if (!mounted) return;
                                              Navigator.of(context).pop(); // Close loading dialog
                                              
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Failed to remove expense: $e')),
                                              );
                                            }
                                          }
                                        },
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                        foregroundColor: Theme.of(context).colorScheme.onError,
                                        icon: Icons.delete,
                                        label: 'Delete',
                                      ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                    child: Text(
                                      expense.paidBy[0],
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
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
                                          color: expense.category.color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );

                            return expenseCard;
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        onPressed: () async {
          final result = await Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              barrierDismissible: true,
              barrierColor: Colors.black.withOpacity(0.5),
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 200),
              pageBuilder: (context, animation, secondaryAnimation) => const AddExpensePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: child,
                  ),
                );
              },
            ),
          );

          if (result is Map) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense added successfully!'),
              ),
            );
            fetchCurrentMonthExpenses(refreshCache: true);
          }
        },
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
                fetchCurrentMonthExpenses(refreshCache: true);
              }
            },
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
            borderRadius: BorderRadius.zero,
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
      return _currencyFormat.format(amount).trim();
    }
    final int thousands = (amount / 1000).round();
    final NumberFormat thousandsFormatter = NumberFormat('#,##0', 'en_US');
    return '${thousandsFormatter.format(thousands)}k';
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
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
