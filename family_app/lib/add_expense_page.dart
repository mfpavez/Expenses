import 'package:family_app/models/category.dart';
import 'package:family_app/services/expense_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final ExpenseService _expenseService = ExpenseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  String? _selectedPaidBy = 'Manuel';
  DateTime _selectedDate = DateTime.now();
  Category _selectedCategory = Category.undefined;
  bool _isAdding = false;

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isAdding = true;
      });
      try {
        await _expenseService.addExpense(
          _itemController.text,
          _selectedPaidBy!,
          double.parse(_amountController.text),
          _selectedDate,
          _selectedCategory.name,
        );

        if (!mounted) return;
        Navigator.of(context).pop({
          'item': _itemController.text,
          'date': _selectedDate,
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add expense: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isAdding = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add New Expense',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 24),
                        const Text('Paid By:', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 8),
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
                            });
                          },
                          emptySelectionAllowed: false,
                          multiSelectionEnabled: false,
                        ),
                        const SizedBox(height: 24),
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
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
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
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isAdding ? null : _submitForm,
                              child: _isAdding
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: SpinKitSpinningLines(
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : const Text('Add'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}