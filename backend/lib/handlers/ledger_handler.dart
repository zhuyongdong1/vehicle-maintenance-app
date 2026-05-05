import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../database/connection.dart';

class LedgerHandler {
  static Future<Response> getList(Request request) async {
    try {
      final params = request.url.queryParameters;
      final type = params['type'];
      final categoryId = params['category_id'];
      final startDate = params['start_date'];
      final endDate = params['end_date'];
      final search = params['search'];

      String sql = '''
        SELECT l.*, c.name as category_name, r.items as related_record_info
        FROM ledger l LEFT JOIN categories c ON l.category_id = c.id LEFT JOIN records r ON l.related_record_id = r.id WHERE 1=1
      ''';
      List<Object?> queryParams = [];
      if (type != null) {
        sql += ' AND l.type = ?';
        queryParams.add(type);
      }
      if (categoryId != null) {
        sql += ' AND l.category_id = ?';
        queryParams.add(int.parse(categoryId));
      }
      if (startDate != null) {
        sql += ' AND l.record_date >= ?';
        queryParams.add(startDate);
      }
      if (endDate != null) {
        sql += ' AND l.record_date <= ?';
        queryParams.add(endDate);
      }
      if (search != null && search.isNotEmpty) {
        sql += ' AND l.description LIKE ?';
        queryParams.add('%$search%');
      }
      sql += ' ORDER BY l.record_date DESC, l.id DESC';
      final results = await Database.instance.query(sql, queryParams);
      return Response.ok(jsonEncode(results.map(_toJson).toList()));
    } catch (e, st) {
      print('LedgerHandler.getList error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> getById(Request request, String id) async {
    final results = await Database.instance.query(
      '''SELECT l.*, c.name as category_name, r.items as related_record_info
         FROM ledger l LEFT JOIN categories c ON l.category_id = c.id LEFT JOIN records r ON l.related_record_id = r.id WHERE l.id = ?''',
      [int.parse(id)],
    );
    if (results.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode(_toJson(results.first)));
  }

  static Future<Response> create(Request request) async {
    final body = jsonDecode(await request.readAsString());
    final id = await Database.instance.insert(
      'INSERT INTO ledger (type, category_id, amount, record_date, description, related_record_id) VALUES (?, ?, ?, ?, ?, ?)',
      [
        body['type'],
        body['category_id'],
        body['amount'],
        body['record_date'],
        body['description'],
        body['related_record_id'],
      ],
    );
    final results = await Database.instance.query(
      '''SELECT l.*, c.name as category_name, r.items as related_record_info
         FROM ledger l LEFT JOIN categories c ON l.category_id = c.id LEFT JOIN records r ON l.related_record_id = r.id WHERE l.id = ?''',
      [id],
    );
    return Response(201, body: jsonEncode(_toJson(results.first)));
  }

  static Future<Response> update(Request request, String id) async {
    final body = jsonDecode(await request.readAsString());
    final ledgerId = int.parse(id);
    final affected = await Database.instance.execute(
      'UPDATE ledger SET type=?, category_id=?, amount=?, record_date=?, description=?, related_record_id=? WHERE id=?',
      [
        body['type'],
        body['category_id'],
        body['amount'],
        body['record_date'],
        body['description'],
        body['related_record_id'],
        ledgerId,
      ],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    final results = await Database.instance.query(
      '''SELECT l.*, c.name as category_name, r.items as related_record_info
         FROM ledger l LEFT JOIN categories c ON l.category_id = c.id LEFT JOIN records r ON l.related_record_id = r.id WHERE l.id = ?''',
      [ledgerId],
    );
    return Response.ok(jsonEncode(_toJson(results.first)));
  }

  static Future<Response> delete(Request request, String id) async {
    final affected = await Database.instance.execute(
      'DELETE FROM ledger WHERE id = ?',
      [int.parse(id)],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode({'success': true}));
  }

  static Future<Response> getStats(Request request) async {
    final period = request.url.queryParameters['period'] ?? 'month';
    String cond = period == 'year'
        ? 'record_date >= DATE_FORMAT(NOW(), "%Y-01-01")'
        : period == 'quarter'
        ? 'record_date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)'
        : 'record_date >= DATE_FORMAT(NOW(), "%Y-%m-01")';
    final incRes = await Database.instance.query(
      "SELECT COALESCE(SUM(amount),0) as total FROM ledger WHERE type='income' AND $cond",
    );
    final expRes = await Database.instance.query(
      "SELECT COALESCE(SUM(amount),0) as total FROM ledger WHERE type='expense' AND $cond",
    );
    final cntRes = await Database.instance.query(
      "SELECT COUNT(*) as cnt FROM records WHERE $cond",
    );
    final income = double.tryParse(incRes.first['total'].toString()) ?? 0.0;
    final expense = double.tryParse(expRes.first['total'].toString()) ?? 0.0;
    return Response.ok(
      jsonEncode({
        'month_income': income,
        'month_expense': expense,
        'month_profit': income - expense,
        'month_record_count': cntRes.first['cnt'] ?? 0,
      }),
    );
  }

  static Map<String, dynamic> _toJson(dynamic r) => {
    'id': r['id'],
    'type': r['type']?.toString(),
    'category_id': r['category_id'],
    'category_name': r['category_name']?.toString(),
    'amount': r['amount'] != null
        ? double.tryParse(r['amount'].toString()) ?? 0.0
        : 0.0,
    'record_date': _fmt(r['record_date']),
    'description': r['description']?.toString(),
    'related_record_id': r['related_record_id'],
    'related_record_info': r['related_record_info']?.toString(),
    'created_at': r['created_at']?.toString(),
    'updated_at': r['updated_at']?.toString(),
  };

  static String _fmt(dynamic v) => v?.toString().split(' ').first ?? '';
}
