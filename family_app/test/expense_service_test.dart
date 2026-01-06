import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:family_app/services/expense_service.dart';
import 'dart:convert';

// Generate a MockClient using the Mockito package.
// Create new instances of this class in each test.
@GenerateMocks([http.Client])
import 'expense_service_test.mocks.dart';

void main() {
  group('ExpenseService', () {
    late ExpenseService expenseService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      expenseService = ExpenseService(client: mockClient);
    });

    test('removeExpense completes successfully on 200 response', () async {
      // Mock the HTTP client to return a a 200 response
      when(
        mockClient.post(
          Uri.parse('https://www.pxghub.com/webhook/remove-expense'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Success', 200));

      expectLater(
        expenseService.removeExpense(123),
        completes,
      );
    });

    test('removeExpense throws exception on non-200 response', () async {
      // Mock the HTTP client to return a non-200 response
      when(
        mockClient.post(
          Uri.parse('https://www.pxghub.com/webhook/remove-expense'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Error occurred', 404));

      expectLater(
        expenseService.removeExpense(123),
        throwsA(isA<Exception>()),
      );
    });
  });
}
