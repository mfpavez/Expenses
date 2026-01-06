import 'dart:convert';
import 'package:family_app/models/category.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseService {
  final http.Client _client;

  // Caching mechanism
  final Map<String, List<Expense>> _cachedExpenses = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheDuration = const Duration(minutes: 5); // Cache for 5 minutes

  final String _n8nWebhookUrl =
      'https://www.pxghub.com/webhook/gastos';
  final String _n8nAddWebhookUrl =
      'https://www.pxghub.com/webhook/add-expense';
  final String _n8nDeleteWebhookUrl =
      'https://www.pxghub.com/webhook/remove-expense';
  final String _n8nUpdateExpenseWebhookUrl =
      'https://www.pxghub.com/webhook/update-expense-category';
  final String _n8nLast3MonthsWebhookUrl = 
      'https://www.pxghub.com/webhook/last-3-months-expenses';

  ExpenseService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Expense>> fetchExpenses(String month, {bool refreshCache = false}) async {
    // Check cache first
    if (!refreshCache && _cachedExpenses.containsKey(month) && _cacheTimestamps.containsKey(month)) {
      if (DateTime.now().difference(_cacheTimestamps[month]!) < _cacheDuration) {
        return _cachedExpenses[month]!;
      }
    }

    final uri = Uri.parse('$_n8nWebhookUrl?month=$month');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final String responseBody = response.body;
      final dynamic decodedJson;
      try {
        decodedJson = json.decode(responseBody);
      } catch (e) {
        throw Exception("Failed to decode JSON. Response body: $responseBody");
      }

      final List<dynamic> expenseJsonList;
      if (decodedJson is List) {
        expenseJsonList = decodedJson;
      } else if (decodedJson is Map) {
        expenseJsonList = [decodedJson];
      } else {
        throw Exception(
          "JSON response is not a List or a Map. Received: $responseBody",
        );
      }

      try {
        final List<Expense> expenseList = expenseJsonList
            .map((json) => Expense.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Cache the data
        _cachedExpenses[month] = expenseList;
        _cacheTimestamps[month] = DateTime.now();
        
        return expenseList;
      } catch (e) {
        // Find the problematic record and throw a more detailed error
        for (var item in expenseJsonList) {
          try {
            Expense.fromJson(item as Map<String, dynamic>);
          } catch (error) {
            throw Exception(
              'Failed to parse an expense record. Error: $error. Problematic JSON: $item',
            );
          }
        }
        // If the loop completes, the error was something else
        throw Exception('Failed to parse expenses: $e');
      }
    } else {
      throw Exception(
        'Failed to load expenses: ${response.statusCode}. Response body: ${response.body}',
      );
    }
  }

  Future<void> removeExpense(int rowNumber) async {
    final uri = Uri.parse(_n8nDeleteWebhookUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'rowNumber': rowNumber,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to remove expense: ${response.statusCode}. Response body: ${response.body}',
      );
    }
  }

  Future<void> updateExpense({
    required int rowNumber,
    required String item,
    required Category category,
    required DateTime date,
    required double amount,
    required String paidBy,
  }) async {
    final uri = Uri.parse(_n8nUpdateExpenseWebhookUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'rowNumber': rowNumber,
        'item': item,
        'category': category.name,
        'date': DateFormat('MM/dd/yy').format(date),
        'amount': amount,
        'paidBy': paidBy,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update expense: ${response.statusCode}. Response body: ${response.body}',
      );
    }
  }

  Future<void> addExpense(
    String item,
    String paidBy,
    double amount,
    DateTime date,
    String categoryName,
  ) async {
    final uri = Uri.parse(_n8nAddWebhookUrl);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'expense_item': item,
        'paidBy': paidBy,
        'amount': amount,
        'date': DateFormat('MM/dd/yy').format(date), // Format date for n8n
        'category': categoryName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to add expense: ${response.statusCode}. Response body: ${response.body}',
      );
    }
  }

  Future<List<Expense>> fetchAllExpenses({bool refreshCache = false}) async {
    const cacheKey = 'allExpenses';
    if (!refreshCache && _cachedExpenses.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      if (DateTime.now().difference(_cacheTimestamps[cacheKey]!) < _cacheDuration) {
        return _cachedExpenses[cacheKey]!;
      }
    }

    final uri = Uri.parse('https://www.pxghub.com/webhook/all-expenses');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final String responseBody = response.body;
      final dynamic decodedJson;
      try {
        decodedJson = json.decode(responseBody);
      } catch (e) {
        throw Exception("Failed to decode JSON. Response body: $responseBody");
      }

      final List<dynamic> expenseJsonList;
      if (decodedJson is List) {
        expenseJsonList = decodedJson;
      } else if (decodedJson is Map) {
        expenseJsonList = [decodedJson];
      } else {
        throw Exception(
          "JSON response is not a List or a Map. Received: $responseBody",
        );
      }

      try {
        final List<Expense> expenseList = expenseJsonList
            .map((json) => Expense.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _cachedExpenses[cacheKey] = expenseList;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        return expenseList;
      } catch (e) {
        for (var item in expenseJsonList) {
          try {
            Expense.fromJson(item as Map<String, dynamic>);
          } catch (error) {
            throw Exception(
              'Failed to parse an expense record. Error: $error. Problematic JSON: $item',
            );
          }
        }
        throw Exception('Failed to parse expenses: $e');
      }
    } else {
      throw Exception(
        'Failed to load expenses: ${response.statusCode}. Response body: ${response.body}',
      );
    }
  }

  Future<List<Expense>> fetchLastThreeMonthsExpenses({bool refreshCache = false}) async {
    const cacheKey = 'lastThreeMonths';
    // Check cache first
    if (!refreshCache && _cachedExpenses.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      if (DateTime.now().difference(_cacheTimestamps[cacheKey]!) < _cacheDuration) {
        return _cachedExpenses[cacheKey]!;
      }
    }

    final uri = Uri.parse(_n8nLast3MonthsWebhookUrl);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final String responseBody = response.body;
      final dynamic decodedJson;
      try {
        decodedJson = json.decode(responseBody);
      } catch (e) {
        throw Exception("Failed to decode JSON. Response body: $responseBody");
      }

      final List<dynamic> expenseJsonList;
      if (decodedJson is List) {
        expenseJsonList = decodedJson;
      } else if (decodedJson is Map) {
        expenseJsonList = [decodedJson];
      } else {
        throw Exception(
          "JSON response is not a List or a Map. Received: $responseBody",
        );
      }

      try {
        final List<Expense> expenseList = expenseJsonList
            .map((json) => Expense.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Cache the data
        _cachedExpenses[cacheKey] = expenseList;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        return expenseList;
      } catch (e) {
        // Find the problematic record and throw a more detailed error
        for (var item in expenseJsonList) {
          try {
            Expense.fromJson(item as Map<String, dynamic>);
          } catch (error) {
            throw Exception(
              'Failed to parse an expense record. Error: $error. Problematic JSON: $item',
            );
          }
        }
        // If the loop completes, the error was something else
        throw Exception('Failed to parse expenses: $e');
      }
    } else {
      throw Exception(
        'Failed to load expenses: ${response.statusCode}. Response body: ${response.body}',
      );
    }
  }
}
