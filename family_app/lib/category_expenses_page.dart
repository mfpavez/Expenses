import 'package:family_app/models/category.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:flutter/material.dart';
import 'package:family_app/models/expense.dart';
import 'package:intl/intl.dart';

class CategoryExpensesPage extends StatefulWidget {
  final String categoryName;
  final List<Expense> expenses;

  const CategoryExpensesPage({
    super.key,
    required this.categoryName,
    required this.expenses,
  });

  @override
  State<CategoryExpensesPage> createState() => _CategoryExpensesPageState();
}

class _CategoryExpensesPageState extends State<CategoryExpensesPage> {
  final ExpenseService _expenseService = ExpenseService();
  late List<Expense> _currentExpenses;
  bool _wasChanged = false;

  @override
  void initState() {
    super.initState();
    _currentExpenses = List.from(widget.expenses);
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

                            _wasChanged = true;
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            
                            // Since we changed something, we should probably pop 
                            // because the expense might not belong here anymore 
                            // (if category changed) or just to refresh everything.
                            Navigator.of(this.context).pop(true); 
                            
                            ScaffoldMessenger.of(this.context).showSnackBar(
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: 'CLP',
      decimalDigits: 0,
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _wasChanged && result == null) {
          // This ensures if they use back button we still signal change if any happened before
          // However, my save logic already pops with true.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.categoryName} Expenses'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_wasChanged),
          ),
        ),
        body: _currentExpenses.isEmpty
            ? const Center(child: Text('No expenses found for this category.'))
            : ListView.builder(
                itemCount: _currentExpenses.length,
                itemBuilder: (context, index) {
                  final expense = _currentExpenses[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    elevation: 2.0,
                    child: ListTile(
                      onTap: () => _showEditExpenseDialog(expense),
                      leading: CircleAvatar(
                        radius: 15,
                        child: Text(expense.paidBy[0]),
                      ),
                      title: Text(expense.item.toUpperCase()),
                      subtitle: Text(
                        '${DateFormat('MM/dd/yy').format(expense.date)} - Paid by ${expense.paidBy}',
                      ),
                      trailing: Text(
                        currencyFormat.format(expense.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}