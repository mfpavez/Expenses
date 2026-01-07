import 'dart:convert';
import 'package:family_app/models/category.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseService {
  static final ExpenseService _instance = ExpenseService._internal();
  factory ExpenseService() => _instance;
  ExpenseService._internal() : _client = http.Client();

  final http.Client _client;

  // Caching mechanism
  final Map<String, List<Expense>> _cachedExpenses = {};
  final Map<String, Map<Category, double>> _cachedBudget = {};
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
  final String _n8nGetBudgetWebhookUrl = 
      'https://www.pxghub.com/webhook/get-budget';
  final String _n8nUpdateBudgetWebhookUrl = 
      'https://www.pxghub.com/webhook/modify-budget';

  Future<Map<Category, double>> fetchBudget({bool refreshCache = false}) async {
    const cacheKey = 'budget';
    // Match the exact caching pattern from fetchExpenses
    if (!refreshCache && _cachedBudget.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
      if (DateTime.now().difference(_cacheTimestamps[cacheKey]!) < _cacheDuration) {
        return _cachedBudget[cacheKey]!;
      }
    }

    final uri = Uri.parse(_n8nGetBudgetWebhookUrl);
    final response = await _client.get(uri);

    print('--- Budget Webhook Debug ---');
    print('URL: $uri');
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode == 200) {
      final dynamic decodedJson;
      try {
        decodedJson = json.decode(response.body);
      } catch (e) {
        throw Exception("Failed to decode budget JSON: $e");
      }

      final List<dynamic> budgetList;
      if (decodedJson is List) {
        budgetList = decodedJson;
      } else if (decodedJson is Map) {
        budgetList = [decodedJson];
      } else {
        throw Exception("Unexpected JSON format for budget");
      }

      final Map<Category, double> budgetMap = {};
      for (var item in budgetList) {
        // Log individual item for deeper debugging
        print('Parsing item: $item');
        
        // Handle potential key variations (n8n often uses Title Case or lowercase)
        final String? categoryStr = (item['category'] ?? item['Category'] ?? item['CATEGORIA']) as String?;
        final category = categoryFromString(categoryStr);
        
        // Budget amount might be 'budget', 'Budget', or 'Presupuesto'
        final rawBudget = item['budget'] ?? item['Budget'] ?? item['presupuesto'];
        final amount = double.tryParse(rawBudget.toString()) ?? 0.0;
        
        if (category != Category.undefined) {
          budgetMap[category] = amount;
          print('Assigned $category: $amount');
        }
      }

      // Cache the data
      _cachedBudget[cacheKey] = budgetMap;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      print('Final Budget Map: $budgetMap');
      print('---------------------------');
      return budgetMap;
    } else {
      throw Exception('Failed to load budget: ${response.statusCode}');
    }
  }

  Future<void> updateBudget(Map<Category, double> budget) async {
    final uri = Uri.parse(_n8nUpdateBudgetWebhookUrl);
    
    // Create a list of objects for easy iteration in n8n
    final List<Map<String, dynamic>> body = budget.entries.map((e) => {
      'category': e.key.name,
      'budget': e.value,
    }).toList();

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update budget: ${response.statusCode}. Body: ${response.body}');
    }
    
    print('--- Update Budget Batch Debug ---');
    print('Items sent: ${body.length}');
    print('Response Code: ${response.statusCode}');
    print('---------------------------');
  }

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

  void _validateResponse(http.Response response, String url, String method, dynamic requestBody) {
    // Debug logging
    print('--- Webhook Debug ---');
    print('URL: $url');
    print('Method: $method');
    print('Request Body: $requestBody');
    print('Response Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('----------------------');

    if (response.statusCode != 200) {
      throw Exception(
        'Failed: ${response.statusCode}. Response body: ${response.body}',
      );
    }

    if (response.body.isEmpty) {
      throw Exception('Server returned an empty response. The operation might have failed remotely.');
    }

    try {
      final dynamic decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('error') && decoded['error'] != null) {
          throw Exception('Webhook error: ${decoded['error']}');
        }
        if (decoded['success'] == false) {
          throw Exception('Webhook failed: ${decoded['message'] ?? "Unknown error"}');
        }
        if (decoded.containsKey('status')) {
           final status = decoded['status'].toString().toLowerCase();
           if (status != 'ok' && status != 'success' && status != '200') {
             throw Exception('Webhook returned bad status: ${decoded['status']}');
           }
        }

        // Check for 'message' indicating failure when no other status is present
        if (decoded.containsKey('message') && !decoded.containsKey('status') && !decoded.containsKey('success')) {
           final message = decoded['message'].toString().toLowerCase();
           if (message.contains('error') || message.contains('fail') || message.contains('not found') || message.contains('issue')) {
              throw Exception('Webhook failed with message: ${decoded['message']}');
           }
        }

        // Check for 'code' which often indicates error in APIs (e.g. 404, 500) even if HTTP status is 200
        if (decoded.containsKey('code')) {
           final code = decoded['code'];
           if (code is int && code != 200) {
             throw Exception('Webhook returned error code: $code. Message: ${decoded['message'] ?? "No message"}');
           }
        }
      }
    } catch (e) {
      final bodyLower = response.body.toLowerCase();
      if (bodyLower.contains('error') || bodyLower.contains('failed')) {
         throw Exception('Webhook response contains error keywords: ${response.body}');
      }
      
      if (e.toString().startsWith('Exception: Webhook')) {
        rethrow;
      }
    }
  }

  Future<void> removeExpense(int rowNumber) async {
    final uri = Uri.parse(_n8nDeleteWebhookUrl);
    final body = {
      'row_number': rowNumber,
    };
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _validateResponse(response, _n8nDeleteWebhookUrl, 'POST', body);
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
    final body = {
      'row_number': rowNumber,
      'item': item,
      'category': category.name,
      'date': DateFormat('MM/dd/yy').format(date),
      'amount': amount,
      'paidBy': paidBy,
    };
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _validateResponse(response, _n8nUpdateExpenseWebhookUrl, 'POST', body);
  }

  Future<void> addExpense(
    String item,
    String paidBy,
    double amount,
    DateTime date,
    String categoryName,
  ) async {
    final uri = Uri.parse(_n8nAddWebhookUrl);
    final body = {
      'expense_item': item,
      'paidBy': paidBy,
      'amount': amount,
      'date': DateFormat('MM/dd/yy').format(date),
      'category': categoryName,
    };
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    _validateResponse(response, _n8nAddWebhookUrl, 'POST', body);
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
}
