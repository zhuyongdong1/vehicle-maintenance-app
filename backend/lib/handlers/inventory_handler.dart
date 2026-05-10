import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../database/connection.dart';

class InventoryHandler {
  static Future<Response> getItems(Request request) async {
    try {
      final params = request.url.queryParameters;
      final search = params['search'];
      final category = params['category'];
      final lowStock = params['low_stock'] == 'true';

      var sql = '''
        SELECT i.*,
          COALESCE(SUM(CASE WHEN t.type = 'in' THEN t.quantity ELSE 0 END), 0) as total_in,
          COALESCE(SUM(CASE WHEN t.type = 'out' THEN t.quantity ELSE 0 END), 0) as total_out
        FROM inventory_items i
        LEFT JOIN inventory_transactions t ON t.item_id = i.id
        WHERE 1=1
      ''';
      final queryParams = <Object?>[];

      if (search != null && search.isNotEmpty) {
        sql += ' AND (i.name LIKE ? OR i.sku LIKE ? OR i.supplier LIKE ?)';
        queryParams.addAll(['%$search%', '%$search%', '%$search%']);
      }
      if (category != null && category.isNotEmpty) {
        sql += ' AND i.category = ?';
        queryParams.add(category);
      }
      if (lowStock) {
        sql += ' AND i.stock_quantity <= i.warning_quantity';
      }

      sql += ' GROUP BY i.id ORDER BY i.updated_at DESC, i.id DESC';
      final results = await Database.instance.query(sql, queryParams);
      return Response.ok(jsonEncode(results.map(_itemToJson).toList()));
    } catch (e, st) {
      print('InventoryHandler.getItems error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> getItemById(Request request, String id) async {
    final results = await Database.instance.query(
      'SELECT * FROM inventory_items WHERE id = ?',
      [int.parse(id)],
    );
    if (results.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode(_itemToJson(results.first)));
  }

  static Future<Response> createItem(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final id = await Database.instance.insert(
        '''INSERT INTO inventory_items
          (name, category, sku, unit, stock_quantity, warning_quantity, purchase_price, sale_price, supplier, location, notes, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())''',
        [
          body['name'],
          body['category'],
          body['sku'],
          body['unit'] ?? '件',
          _intValue(body['stock_quantity']),
          _intValue(body['warning_quantity'], fallback: 5),
          _numValue(body['purchase_price']),
          _numValue(body['sale_price']),
          body['supplier'],
          body['location'],
          body['notes'],
        ],
      );
      final results = await Database.instance.query(
        'SELECT * FROM inventory_items WHERE id = ?',
        [id],
      );
      return Response(201, body: jsonEncode(_itemToJson(results.first)));
    } catch (e, st) {
      print('InventoryHandler.createItem error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> updateItem(Request request, String id) async {
    try {
      final itemId = int.parse(id);
      final body = jsonDecode(await request.readAsString());
      final item = await Database.instance.transaction((db) async {
        final existing = await db.query(
          'SELECT stock_quantity FROM inventory_items WHERE id = ? FOR UPDATE',
          [itemId],
        );
        if (existing.isEmpty) return null;

        final oldStock = _intValue(existing.first['stock_quantity']);
        final newStock = _intValue(body['stock_quantity']);
        await db.execute(
          '''UPDATE inventory_items SET
            name=?, category=?, sku=?, unit=?, stock_quantity=?, warning_quantity=?,
            purchase_price=?, sale_price=?, supplier=?, location=?, notes=?, updated_at=NOW()
            WHERE id=?''',
          [
            body['name'],
            body['category'],
            body['sku'],
            body['unit'] ?? '件',
            newStock,
            _intValue(body['warning_quantity'], fallback: 5),
            _numValue(body['purchase_price']),
            _numValue(body['sale_price']),
            body['supplier'],
            body['location'],
            body['notes'],
            itemId,
          ],
        );

        final delta = newStock - oldStock;
        if (delta != 0) {
          await db.insert(
            '''INSERT INTO inventory_transactions
              (item_id, type, quantity, unit_price, related_record_id, operator, notes)
              VALUES (?, 'adjust', ?, ?, NULL, ?, ?)''',
            [
              itemId,
              delta.abs(),
              _numValue(body['purchase_price']),
              body['operator'],
              '库存校准：$oldStock -> $newStock',
            ],
          );
        }

        final results = await db.query(
          'SELECT * FROM inventory_items WHERE id = ?',
          [itemId],
        );
        return results.first;
      });
      if (item == null) {
        return Response.notFound(jsonEncode({'error': 'Not found'}));
      }
      return Response.ok(jsonEncode(_itemToJson(item)));
    } catch (e, st) {
      print('InventoryHandler.updateItem error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> deleteItem(Request request, String id) async {
    final affected = await Database.instance.execute(
      'DELETE FROM inventory_items WHERE id = ?',
      [int.parse(id)],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode({'success': true}));
  }

  static Future<Response> getTransactions(Request request) async {
    try {
      final params = request.url.queryParameters;
      final itemId = params['item_id'];
      final type = params['type'];

      var sql = '''
        SELECT t.*, i.name as item_name, i.sku as item_sku, r.items as related_record_info
        FROM inventory_transactions t
        LEFT JOIN inventory_items i ON t.item_id = i.id
        LEFT JOIN records r ON t.related_record_id = r.id
        WHERE 1=1
      ''';
      final queryParams = <Object?>[];
      if (itemId != null) {
        sql += ' AND t.item_id = ?';
        queryParams.add(int.parse(itemId));
      }
      if (type != null && type.isNotEmpty) {
        sql += ' AND t.type = ?';
        queryParams.add(type);
      }
      sql += ' ORDER BY t.created_at DESC, t.id DESC LIMIT 100';

      final results = await Database.instance.query(sql, queryParams);
      return Response.ok(jsonEncode(results.map(_transactionToJson).toList()));
    } catch (e, st) {
      print('InventoryHandler.getTransactions error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> createTransaction(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final itemId = _intValue(body['item_id']);
      final type = body['type']?.toString() ?? 'in';
      final quantity = _intValue(body['quantity']);
      if (itemId <= 0 || quantity <= 0) {
        return Response(400, body: jsonEncode({'error': 'Invalid payload'}));
      }

      final tx = await Database.instance.transaction((db) async {
        final stockDelta = type == 'out' ? -quantity : quantity;
        final affected = await db.execute(
          'UPDATE inventory_items SET stock_quantity = stock_quantity + ? WHERE id = ? AND stock_quantity + ? >= 0',
          [stockDelta, itemId, stockDelta],
        );
        if (affected == 0) return null;

        final id = await db.insert(
          '''INSERT INTO inventory_transactions
            (item_id, type, quantity, unit_price, related_record_id, operator, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            itemId,
            type,
            quantity,
            _numValue(body['unit_price']),
            body['related_record_id'],
            body['operator'],
            body['notes'],
          ],
        );
        final results = await db.query(
          '''SELECT t.*, i.name as item_name, i.sku as item_sku, r.items as related_record_info
             FROM inventory_transactions t
             LEFT JOIN inventory_items i ON t.item_id = i.id
             LEFT JOIN records r ON t.related_record_id = r.id
             WHERE t.id = ?''',
          [id],
        );
        return results.first;
      });
      if (tx == null) {
        return Response(400, body: jsonEncode({'error': '库存不足或配件不存在'}));
      }
      return Response(201, body: jsonEncode(_transactionToJson(tx)));
    } catch (e, st) {
      print('InventoryHandler.createTransaction error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> getStats(Request request) async {
    try {
      final totals = await Database.instance.query('''
        SELECT
          COUNT(*) as item_count,
          COALESCE(SUM(stock_quantity), 0) as stock_count,
          COALESCE(SUM(stock_quantity * purchase_price), 0) as stock_value,
          SUM(CASE WHEN stock_quantity <= warning_quantity THEN 1 ELSE 0 END) as warning_count
        FROM inventory_items
      ''');
      final categories = await Database.instance.query('''
        SELECT COALESCE(category, '未分类') as category, COUNT(*) as item_count,
          COALESCE(SUM(stock_quantity), 0) as stock_count
        FROM inventory_items
        GROUP BY COALESCE(category, '未分类')
        ORDER BY item_count DESC
      ''');
      final recent = await Database.instance.query('''
        SELECT t.*, i.name as item_name, i.sku as item_sku
        FROM inventory_transactions t
        LEFT JOIN inventory_items i ON t.item_id = i.id
        ORDER BY t.created_at DESC, t.id DESC LIMIT 10
      ''');
      final first = totals.first;
      return Response.ok(
        jsonEncode({
          'item_count': first['item_count'] ?? 0,
          'stock_count': _intValue(first['stock_count']),
          'stock_value': _double(first['stock_value']),
          'warning_count': _intValue(first['warning_count']),
          'categories': categories
              .map(
                (r) => {
                  'category': r['category']?.toString(),
                  'item_count': _intValue(r['item_count']),
                  'stock_count': _intValue(r['stock_count']),
                },
              )
              .toList(),
          'recent_transactions': recent.map(_transactionToJson).toList(),
        }),
      );
    } catch (e, st) {
      print('InventoryHandler.getStats error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Map<String, dynamic> _itemToJson(dynamic r) => {
    'id': r['id'],
    'name': r['name']?.toString(),
    'category': r['category']?.toString(),
    'sku': r['sku']?.toString(),
    'unit': r['unit']?.toString() ?? '件',
    'stock_quantity': r['stock_quantity'] ?? 0,
    'warning_quantity': r['warning_quantity'] ?? 0,
    'purchase_price': _double(r['purchase_price']),
    'sale_price': _double(r['sale_price']),
    'supplier': r['supplier']?.toString(),
    'location': r['location']?.toString(),
    'notes': r['notes']?.toString(),
    'total_in': r['total_in'] ?? 0,
    'total_out': r['total_out'] ?? 0,
    'created_at': r['created_at']?.toString(),
    'updated_at': r['updated_at']?.toString(),
  };

  static Map<String, dynamic> _transactionToJson(dynamic r) => {
    'id': r['id'],
    'item_id': r['item_id'],
    'item_name': r['item_name']?.toString(),
    'item_sku': r['item_sku']?.toString(),
    'type': r['type']?.toString(),
    'quantity': r['quantity'] ?? 0,
    'unit_price': _double(r['unit_price']),
    'related_record_id': r['related_record_id'],
    'related_record_info': r['related_record_info']?.toString(),
    'operator': r['operator']?.toString(),
    'notes': r['notes']?.toString(),
    'created_at': r['created_at']?.toString(),
  };

  static int _intValue(dynamic value, {int fallback = 0}) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  static double _numValue(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
}
