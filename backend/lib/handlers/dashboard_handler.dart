import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../database/connection.dart';

class DashboardHandler {
  static Future<Response> getStats(Request request) async {
    try {
      final incRes = await Database.instance.query(
        "SELECT COALESCE(SUM(amount),0) as total FROM ledger WHERE type='income' AND record_date >= DATE_FORMAT(NOW(), '%Y-%m-01')",
      );
      final expRes = await Database.instance.query(
        "SELECT COALESCE(SUM(amount),0) as total FROM ledger WHERE type='expense' AND record_date >= DATE_FORMAT(NOW(), '%Y-%m-01')",
      );
      final cntRes = await Database.instance.query(
        "SELECT COUNT(*) as cnt FROM records WHERE record_date >= DATE_FORMAT(NOW(), '%Y-%m-01')",
      );
      final income = (incRes.isNotEmpty)
          ? (double.tryParse(incRes.first['total'].toString()) ?? 0.0)
          : 0.0;
      final expense = (expRes.isNotEmpty)
          ? (double.tryParse(expRes.first['total'].toString()) ?? 0.0)
          : 0.0;
      final count = (cntRes.isNotEmpty) ? (cntRes.first['cnt'] ?? 0) : 0;

      final reminders = await Database.instance.query('''
        SELECT v.plate_number, r.reminder_date, r.reminder_mileage, DATEDIFF(r.reminder_date, CURDATE()) as days_left
        FROM records r JOIN vehicles v ON r.vehicle_id = v.id WHERE r.reminder_date IS NOT NULL ORDER BY r.reminder_date ASC LIMIT 5
      ''');
      final recentRecords = await Database.instance.query('''
        SELECT r.*, v.plate_number, c.name as category_name
        FROM records r LEFT JOIN vehicles v ON r.vehicle_id = v.id LEFT JOIN categories c ON r.category_id = c.id ORDER BY r.created_at DESC LIMIT 5
      ''');
      final recentLedger = await Database.instance.query('''
        SELECT l.*, c.name as category_name FROM ledger l LEFT JOIN categories c ON l.category_id = c.id ORDER BY l.created_at DESC LIMIT 5
      ''');

      return Response.ok(
        jsonEncode({
          'month_income': income,
          'month_expense': expense,
          'month_profit': income - expense,
          'month_record_count': count,
          'reminders': reminders
              .map(
                (r) => {
                  'plate_number': r['plate_number']?.toString(),
                  'reminder_date': r['reminder_date']
                      ?.toString()
                      .split(' ')
                      .first,
                  'reminder_mileage': r['reminder_mileage'],
                  'days_left': r['days_left'],
                },
              )
              .toList(),
          'recent_records': recentRecords
              .map(
                (r) => {
                  'id': r['id'],
                  'plate_number': r['plate_number']?.toString(),
                  'category_name': r['category_name']?.toString(),
                  'items': r['items']?.toString(),
                  'cost': r['cost'] != null
                      ? double.tryParse(r['cost'].toString())
                      : null,
                  'record_date': r['record_date']?.toString().split(' ').first,
                },
              )
              .toList(),
          'recent_ledger': recentLedger
              .map(
                (r) => {
                  'id': r['id'],
                  'type': r['type']?.toString(),
                  'category_name': r['category_name']?.toString(),
                  'amount': r['amount'] != null
                      ? double.tryParse(r['amount'].toString())
                      : 0.0,
                  'record_date': r['record_date']?.toString().split(' ').first,
                  'description': r['description']?.toString(),
                },
              )
              .toList(),
        }),
      );
    } catch (e, st) {
      print('DashboardHandler.getStats error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }
}
