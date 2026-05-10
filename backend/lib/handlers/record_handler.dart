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
            ' AND (r.items LIKE ? OR r.notes LIKE ? OR r.workshop LIKE ? OR v.plate_number LIKE ?)';
        queryParams.addAll([
          '%$search%',
          '%$search%',
          '%$search%',
          '%$search%',
        ]);
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
    final record = await Database.instance.transaction((db) async {
      final id = await db.insert(
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
        await _syncLedgerEntries(db, id, body, createMissing: true);
      }
      return _fetchRecordById(db, id);
    });
    return Response(201, body: jsonEncode(_toJson(record)));
  }

  static Future<Response> update(Request request, String id) async {
    final body = jsonDecode(await request.readAsString());
    final recordId = int.parse(id);
    final record = await Database.instance.transaction((db) async {
      final affected = await db.execute(
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
      if (affected == 0) return null;
      await _syncLedgerEntries(
        db,
        recordId,
        body,
        createMissing: body['create_ledger'] == true,
      );
      return _fetchRecordById(db, recordId);
    });
    if (record == null) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode(_toJson(record)));
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

  static Future<Response> settle(Request request, String id) async {
    final recordId = int.parse(id);
    try {
      final record = await Database.instance.transaction((db) async {
        final records = await db.query(
          'SELECT * FROM records WHERE id = ? FOR UPDATE',
          [recordId],
        );
        if (records.isEmpty) return null;
        final row = records.first;
        final amount = _amount(row['cost']);
        if (amount <= 0) {
          throw const _BadRequest('请先填写工单金额');
        }
        await _syncLedgerEntry(
          db,
          recordId: recordId,
          type: 'income',
          categoryId: await _ledgerCategoryId(db, 'ledger_income', '维修收入'),
          amount: amount,
          recordDate: row['record_date'],
          description: _nonEmpty(row['items']) ?? '维修收入',
          createMissing: true,
        );
        await db.execute('UPDATE records SET status = ? WHERE id = ?', [
          'settled',
          recordId,
        ]);
        return _fetchRecordById(db, recordId);
      });
      if (record == null) {
        return Response.notFound(jsonEncode({'error': 'Not found'}));
      }
      return Response.ok(jsonEncode(_toJson(record)));
    } on _BadRequest catch (e) {
      return Response(400, body: jsonEncode({'error': e.message}));
    }
  }

  static Future<Response> delete(Request request, String id) async {
    final recordId = int.parse(id);
    final affected = await Database.instance.transaction((db) async {
      await db.execute(
        'UPDATE ledger SET related_record_id = NULL WHERE related_record_id = ?',
        [recordId],
      );
      return db.execute('DELETE FROM records WHERE id = ?', [recordId]);
    });
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

  static Future<dynamic> _fetchRecordById(DatabaseExecutor db, int id) async {
    final results = await db.query(
      '''SELECT r.*, v.plate_number, CONCAT(COALESCE(v.brand,''), ' ', COALESCE(v.model,'')) as vehicle_info, c.name as category_name
         FROM records r LEFT JOIN vehicles v ON r.vehicle_id = v.id LEFT JOIN categories c ON r.category_id = c.id WHERE r.id = ?''',
      [id],
    );
    if (results.isEmpty) {
      throw StateError('Record $id not found after write');
    }
    return results.first;
  }

  static Future<void> _syncLedgerEntries(
    DatabaseExecutor db,
    int recordId,
    Map<String, dynamic> body, {
    required bool createMissing,
  }) async {
    final items = _nonEmpty(body['items']) ?? '维修项目';
    final recordDate = body['record_date'];
    await _syncLedgerEntry(
      db,
      recordId: recordId,
      type: 'income',
      categoryId: await _ledgerCategoryId(db, 'ledger_income', '维修收入'),
      amount: _amount(body['cost']),
      recordDate: recordDate,
      description: _nonEmpty(body['items']) ?? '维修收入',
      createMissing: createMissing,
    );
    await _syncLedgerEntry(
      db,
      recordId: recordId,
      type: 'expense',
      categoryId: await _ledgerCategoryId(db, 'ledger_expense', '配件采购'),
      amount: _amount(body['purchase_cost']),
      recordDate: recordDate,
      description: '$items进价',
      createMissing: createMissing,
    );
  }

  static Future<void> _syncLedgerEntry(
    DatabaseExecutor db, {
    required int recordId,
    required String type,
    required int? categoryId,
    required double amount,
    required dynamic recordDate,
    required String description,
    required bool createMissing,
  }) async {
    final existing = await db.query(
      'SELECT id FROM ledger WHERE related_record_id = ? AND type = ? ORDER BY id LIMIT 1',
      [recordId, type],
    );
    if (existing.isNotEmpty) {
      await db.execute(
        '''UPDATE ledger
           SET category_id = ?, amount = ?, record_date = ?, description = ?
           WHERE id = ?''',
        [categoryId, amount, recordDate, description, existing.first['id']],
      );
      return;
    }
    if (!createMissing || amount <= 0) return;
    await db.insert(
      '''INSERT INTO ledger
         (type, category_id, amount, record_date, description, related_record_id)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [type, categoryId, amount, recordDate, description, recordId],
    );
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Future<int?> _ledgerCategoryId(
    DatabaseExecutor db,
    String type,
    String name,
  ) async {
    final results = await db.query(
      'SELECT id FROM categories WHERE type = ? AND name = ? LIMIT 1',
      [type, name],
    );
    return results.isEmpty ? null : results.first['id'] as int?;
  }
}

class _BadRequest implements Exception {
  final String message;

  const _BadRequest(this.message);
}
