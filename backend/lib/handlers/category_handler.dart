import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../database/connection.dart';

class CategoryHandler {
  static Future<Response> getList(Request request) async {
    try {
      final type = request.url.queryParameters['type'];
      String sql = 'SELECT * FROM categories';
      List<Object?> params = [];
      if (type != null) {
        sql += ' WHERE type = ?';
        params.add(type);
      }
      sql += ' ORDER BY sort_order ASC, created_at DESC';

      final results = await Database.instance.query(sql, params);
      final categories = results
          .map(
            (r) => {
              'id': r['id'],
              'name': r['name']?.toString(),
              'type': r['type']?.toString(),
              'sort_order': r['sort_order'],
              'created_at': r['created_at']?.toString(),
            },
          )
          .toList();
      return Response.ok(jsonEncode(categories));
    } catch (e, st) {
      print('CategoryHandler.getList error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> create(Request request) async {
    final body = jsonDecode(await request.readAsString());
    final id = await Database.instance.insert(
      'INSERT INTO categories (type, name, sort_order) VALUES (?, ?, ?)',
      [body['type'], body['name'], body['sort_order'] ?? 0],
    );
    return Response(201, body: jsonEncode(await _getById(id)));
  }

  static Future<Response> update(Request request, String id) async {
    final body = jsonDecode(await request.readAsString());
    final categoryId = int.parse(id);
    final affected = await Database.instance.execute(
      'UPDATE categories SET name=?, sort_order=? WHERE id=?',
      [body['name'], body['sort_order'] ?? 0, categoryId],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode(await _getById(categoryId)));
  }

  static Future<Response> delete(Request request, String id) async {
    final affected = await Database.instance.execute(
      'DELETE FROM categories WHERE id = ?',
      [int.parse(id)],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode({'success': true}));
  }

  static Future<Map<String, dynamic>> _getById(int id) async {
    final results = await Database.instance.query(
      'SELECT * FROM categories WHERE id = ?',
      [id],
    );
    final r = results.first;
    return {
      'id': r['id'],
      'name': r['name']?.toString(),
      'type': r['type']?.toString(),
      'sort_order': r['sort_order'],
      'created_at': r['created_at']?.toString(),
    };
  }
}
