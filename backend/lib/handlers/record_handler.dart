import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../database/connection.dart';

class RecordHandler {
  static Future<Response> getList(Request request) async {
    try {
      final params = request.url.queryParameters;
      final vehicleId = params['vehicle_id'];
      final categoryId = params['category_id'];
      final search = params['search'];

      String sql = '''
        SELECT r.*, v.plate_number,
          CONCAT(COALESCE(v.brand,''), ' ', COALESCE(v.model,'')) as vehicle_info,
          c.name as category_name
        FROM records r
        LEFT JOIN vehicles v ON r.vehicle_id = v.id
        LEFT JOIN categories c ON r.category_id = c.id
        WHERE 1=1
      ''';
      List<Object?> queryParams = [];
      if (vehicleId != null) {
        sql += ' AND r.vehicle_id = ?';
        queryParams.add(int.parse(vehicleId));
      }
      if (categoryId != null) {
        sql += ' AND r.category_id = ?';
        queryParams.add(int.parse(categoryId));
      }
      if (search != null && search.isNotEmpty) {
        sql +=
            ' AND (r.items LIKE ? OR r.notes LIKE ? OR v.plate_number LIKE ?)';
        queryParams.addAll(['%$search%', '%$search%', '%$search%']);
      }
      sql += ' ORDER BY r.record_date DESC';
      final results = await Database.instance.query(sql, queryParams);
      return Response.ok(jsonEncode(results.map(_toJson).toList()));
    } catch (e, st) {
      print('RecordHandler.getList error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> getById(Request request, String id) async {
    final results = await Database.instance.query(
      '''SELECT r.*, v.plate_number, CONCAT(COALESCE(v.brand,''), ' ', COALESCE(v.model,'')) as vehicle_info, c.name as category_name
         FROM records r LEFT JOIN vehicles v ON r.vehicle_id = v.id LEFT JOIN categories c ON r.category_id = c.id WHERE r.id = ?''',
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
      '''INSERT INTO records (vehicle_id, category_id, status, items, cost, purchase_cost, mileage, record_date, workshop, notes, parts, fee_items, reminder_date, reminder_mileage)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        body['vehicle_id'],
        body['category_id'],
        _normalizeStatus(body['status']) ?? 'pending',
        body['items'],
        body['cost'],
        body['purchase_cost'],
        body['mileage'],
        body['record_date'],
        body['workshop'],
        body['notes'],
        body['parts'],
        _encodeFeeItems(body['fee_items']),
        body['reminder_date'],
        body['reminder_mileage'],
      ],
    );

    if (body['create_ledger'] == true) {
      try {
        final saleAmount = _amount(body['cost']);
        final purchaseAmount = _amount(body['purchase_cost']);
        if (saleAmount > 0) {
          await Database.instance.insert(
            "INSERT INTO ledger (type, category_id, amount, record_date, description, related_record_id) VALUES ('income', ?, ?, ?, ?, ?)",
            [
              await _ledgerCategoryId('ledger_income', '维修收入'),
              saleAmount,
              body['record_date'],
              body['items']?.toString() ?? '维修收入',
              id,
            ],
          );
        }
        if (purchaseAmount > 0) {
          await Database.instance.insert(
            "INSERT INTO ledger (type, category_id, amount, record_date, description, related_record_id) VALUES ('expense', ?, ?, ?, ?, ?)",
            [
              await _ledgerCategoryId('ledger_expense', '配件采购'),
              purchaseAmount,
              body['record_date'],
              '${body['items']?.toString() ?? '维修项目'}进价',
              id,
            ],
          );
        }
      } catch (e) {
        print('Auto ledger creation failed: $e');
      }
    }
    final results = await Database.instance.query(
      '''SELECT r.*, v.plate_number, CONCAT(COALESCE(v.brand,''), ' ', COALESCE(v.model,'')) as vehicle_info, c.name as category_name
         FROM records r LEFT JOIN vehicles v ON r.vehicle_id = v.id LEFT JOIN categories c ON r.category_id = c.id WHERE r.id = ?''',
      [id],
    );
    return Response(201, body: jsonEncode(_toJson(results.first)));
  }

  static Future<Response> update(Request request, String id) async {
    final body = jsonDecode(await request.readAsString());
    final recordId = int.parse(id);
    final affected = await Database.instance.execute(
      '''UPDATE records SET vehicle_id=?, category_id=?, status=?, items=?, cost=?, purchase_cost=?, mileage=?, record_date=?, workshop=?, notes=?, parts=?, fee_items=?, reminder_date=?, reminder_mileage=? WHERE id=?''',
      [
        body['vehicle_id'],
        body['category_id'],
        _normalizeStatus(body['status']) ?? 'pending',
        body['items'],
        body['cost'],
        body['purchase_cost'],
        body['mileage'],
        body['record_date'],
        body['workshop'],
        body['notes'],
        body['parts'],
        _encodeFeeItems(body['fee_items']),
        body['reminder_date'],
        body['reminder_mileage'],
        recordId,
      ],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    final results = await Database.instance.query(
      '''SELECT r.*, v.plate_number, CONCAT(COALESCE(v.brand,''), ' ', COALESCE(v.model,'')) as vehicle_info, c.name as category_name
         FROM records r LEFT JOIN vehicles v ON r.vehicle_id = v.id LEFT JOIN categories c ON r.category_id = c.id WHERE r.id = ?''',
      [recordId],
    );
    return Response.ok(jsonEncode(_toJson(results.first)));
  }

  static Future<Response> updateStatus(Request request, String id) async {
    final body = jsonDecode(await request.readAsString());
    final status = _normalizeStatus(body['status']);
    if (status == null) {
      return Response(400, body: jsonEncode({'error': 'Invalid status'}));
    }
    final recordId = int.parse(id);
    final affected = await Database.instance.execute(
      'UPDATE records SET status = ? WHERE id = ?',
      [status, recordId],
    );
    final results = await Database.instance.query(
      '''SELECT r.*, v.plate_number, CONCAT(COALESCE(v.brand,''), ' ', COALESCE(v.model,'')) as vehicle_info, c.name as category_name
         FROM records r LEFT JOIN vehicles v ON r.vehicle_id = v.id LEFT JOIN categories c ON r.category_id = c.id WHERE r.id = ?''',
      [recordId],
    );
    if (affected == 0 && results.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode(_toJson(results.first)));
  }

  static Future<Response> delete(Request request, String id) async {
    final affected = await Database.instance.execute(
      'DELETE FROM records WHERE id = ?',
      [int.parse(id)],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode({'success': true}));
  }

  static Map<String, dynamic> _toJson(dynamic r) => {
    'id': r['id'],
    'vehicle_id': r['vehicle_id'],
    'category_id': r['category_id'],
    'status': r['status']?.toString() ?? 'pending',
    'category_name': r['category_name']?.toString(),
    'items': r['items']?.toString(),
    'cost': r['cost'] != null ? double.tryParse(r['cost'].toString()) : null,
    'purchase_cost': r['purchase_cost'] != null
        ? double.tryParse(r['purchase_cost'].toString())
        : null,
    'mileage': r['mileage'],
    'record_date': _fmt(r['record_date']),
    'workshop': r['workshop']?.toString(),
    'notes': r['notes']?.toString(),
    'parts': r['parts']?.toString(),
    'fee_items': r['fee_items']?.toString(),
    'reminder_date': _fmt(r['reminder_date']),
    'reminder_mileage': r['reminder_mileage'],
    'plate_number': r['plate_number']?.toString(),
    'vehicle_info': r['vehicle_info']?.toString(),
    'created_at': r['created_at']?.toString(),
    'updated_at': r['updated_at']?.toString(),
  };

  static String _fmt(dynamic v) => v?.toString().split(' ').first ?? '';

  static String? _encodeFeeItems(dynamic value) {
    if (value == null) return null;
    return value is String ? value : jsonEncode(value);
  }

  static double _amount(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static String? _normalizeStatus(dynamic value) {
    final status = value?.toString();
    if (status == null || status.isEmpty) return null;
    return {'pending', 'repairing', 'completed', 'settled'}.contains(status)
        ? status
        : null;
  }

  static Future<int?> _ledgerCategoryId(String type, String name) async {
    final results = await Database.instance.query(
      'SELECT id FROM categories WHERE type = ? AND name = ? LIMIT 1',
      [type, name],
    );
    return results.isEmpty ? null : results.first['id'] as int?;
  }
}
