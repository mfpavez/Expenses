import 'package:family_app/models/category.dart';
import 'package:intl/intl.dart';

class Expense {
  final String item;
  final DateTime date;
  final String paidBy;
  final double amount;
  final int? rowNumber;
  final bool isX2;
  final Category category;

  Expense({
    required this.item,
    required this.date,
    required this.paidBy,
    required this.amount,
    this.rowNumber,
    required this.category,
  }) : isX2 = item.toLowerCase().contains('x2');

  factory Expense.fromJson(Map<String, dynamic> json) {
    // Helper to convert Excel date serial number to DateTime
    DateTime excelSerialToDateTime(int serial) {
      // Excel epoch is January 1, 1900. Dart's DateTime epoch is January 1, 1970.
      // Adjusting for the difference in days. Excel's 1900 is a leap year bug.
      // serial 1 is Jan 1, 1900.
      // serial 61 is Mar 1, 1900 (skipping non-existent Feb 29, 1900)
      // Correct epoch start for calculation: Dec 30, 1899 (day 0)
      final DateTime excelEpoch = DateTime.utc(1899, 12, 30);
      return excelEpoch.add(Duration(days: serial));
    }

    double parsedAmount = 0.0;
    if (json['expenses'] != null) {
      // Changed from 'amount' to 'expenses'
      parsedAmount =
          double.tryParse(json['expenses'].toString()) ??
          0.0; // Assume it's a number, no comma replacement needed if it's a direct number
    }

    DateTime parsedDate;
    if (json['Fecha'] != null) {
      var fechaValue = json['Fecha'];
      if (fechaValue is int) {
        parsedDate = excelSerialToDateTime(fechaValue);
      } else if (fechaValue is String) {
        int? serialDate = int.tryParse(fechaValue);
        if (serialDate != null) {
          parsedDate = excelSerialToDateTime(serialDate);
        } else {
          // List of possible date formats
          final List<String> dateFormats = [
            'M/d/yy',
            'MM-dd-yy',
            'MM/dd/yy',
            'MM-d-yy',
          ];

          DateTime? tempDate;
          for (String format in dateFormats) {
            try {
              tempDate = DateFormat(format).parse(fechaValue);
              break; // If parsing is successful, break the loop
            } catch (e) {
              // Continue to the next format
            }
          }
          parsedDate =
              tempDate ?? DateTime(1970); // Use the parsed date or fallback
        }
      } else {
        parsedDate = DateTime(1970); // Fallback
      }
    } else {
      parsedDate = DateTime(1970);
    }

    return Expense(
      item:
          json['ITEM'] as String? ?? 'No Item', // Changed from 'item' to 'ITEM'
      date: parsedDate,
      paidBy: json['paidBy'] as String? ?? 'Unknown',
      amount: parsedAmount,
      rowNumber: json['row_number'] as int?, // Parse rowNumber
      category: categoryFromString(json['category'] as String?),
    );
  }

  @override
  String toString() {
    return 'Expense{item: $item, date: $date, paidBy: $paidBy, amount: $amount, rowNumber: $rowNumber, isX2: $isX2, category: $category}';
  }
}
