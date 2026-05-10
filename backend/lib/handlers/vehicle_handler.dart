import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../database/connection.dart';

class VehicleHandler {
  static Future<Response> getList(Request request) async {
    try {
      final search = request.url.queryParameters['search'];
      String sql = '''
        SELECT v.*,
          (SELECT COUNT(*) FROM records r WHERE r.vehicle_id = v.id) as record_count,
          (SELECT SUM(cost) FROM records r WHERE r.vehicle_id = v.id) as total_cost,
          (SELECT MAX(record_date) FROM records r WHERE r.vehicle_id = v.id) as last_record_date
        FROM vehicles v WHERE v.deleted_at IS NULL
      ''';
      List<Object?> params = [];
      if (search != null && search.isNotEmpty) {
        sql +=
            ' AND (v.plate_number LIKE ? OR v.vin LIKE ? OR v.owner_name LIKE ? OR v.owner_phone LIKE ?)';
        params.addAll(['%$search%', '%$search%', '%$search%', '%$search%']);
      }
      sql += ' ORDER BY v.updated_at DESC';
      final results = await Database.instance.query(sql, params);
      return Response.ok(jsonEncode(results.map(_toJson).toList()));
    } catch (e, st) {
      print('VehicleHandler.getList error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> getById(Request request, String id) async {
    try {
      final results = await Database.instance.query(
        '''SELECT v.*,
          (SELECT COUNT(*) FROM records r WHERE r.vehicle_id = v.id) as record_count,
          (SELECT SUM(cost) FROM records r WHERE r.vehicle_id = v.id) as total_cost
        FROM vehicles v WHERE v.id = ? AND v.deleted_at IS NULL''',
        [int.parse(id)],
      );
      if (results.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Not found'}));
      }
      return Response.ok(jsonEncode(_toJson(results.first)));
    } catch (e, st) {
      print('VehicleHandler.getById error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static Future<Response> create(Request request) async {
    final body = jsonDecode(await request.readAsString());
    final plateNumber = body['plate_number']?.toString().trim();
    if (plateNumber == null || plateNumber.isEmpty) {
      return Response(400, body: jsonEncode({'error': '车牌号不能为空'}));
    }
    final existing = await Database.instance.query(
      'SELECT * FROM vehicles WHERE plate_number = ? AND deleted_at IS NULL LIMIT 1',
      [plateNumber],
    );
    if (existing.isNotEmpty) {
      return Response.ok(jsonEncode(_toJson(existing.first)));
    }
    final deleted = await Database.instance.query(
      'SELECT id FROM vehicles WHERE plate_number = ? AND deleted_at IS NOT NULL LIMIT 1',
      [plateNumber],
    );
    if (deleted.isNotEmpty) {
      final vehicleId = deleted.first['id'];
      await Database.instance.execute(
        '''UPDATE vehicles SET deleted_at=NULL, vin=?, brand=?, model=?, year=?, color=?, owner_name=?, owner_phone=?, photo_url=?, inspection_date=?, insurance_date=?
           WHERE id=?''',
        [
          body['vin'],
          body['brand'],
          body['model'],
          body['year'],
          body['color'],
          body['owner_name'],
          body['owner_phone'],
          body['photo_url'],
          body['inspection_date'],
          body['insurance_date'],
          vehicleId,
        ],
      );
      final results = await Database.instance.query(
        'SELECT * FROM vehicles WHERE id = ?',
        [vehicleId],
      );
      return Response(201, body: jsonEncode(_toJson(results.first)));
    }
    final id = await Database.instance.insert(
      '''INSERT INTO vehicles (plate_number, vin, brand, model, year, color, owner_name, owner_phone, photo_url, inspection_date, insurance_date)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        plateNumber,
        body['vin'],
        body['brand'],
        body['model'],
        body['year'],
        body['color'],
        body['owner_name'],
        body['owner_phone'],
        body['photo_url'],
        body['inspection_date'],
        body['insurance_date'],
      ],
    );
    final results = await Database.instance.query(
      'SELECT * FROM vehicles WHERE id = ?',
      [id],
    );
    return Response(201, body: jsonEncode(_toJson(results.first)));
  }

  static Future<Response> update(Request request, String id) async {
    final body = jsonDecode(await request.readAsString());
    final vehicleId = int.parse(id);
    final plateNumber = body['plate_number']?.toString().trim();
    if (plateNumber == null || plateNumber.isEmpty) {
      return Response(400, body: jsonEncode({'error': '车牌号不能为空'}));
    }
    final duplicate = await Database.instance.query(
      'SELECT id FROM vehicles WHERE plate_number = ? AND id <> ? AND deleted_at IS NULL LIMIT 1',
      [plateNumber, vehicleId],
    );
    if (duplicate.isNotEmpty) {
      return Response(409, body: jsonEncode({'error': '该车牌号已存在'}));
    }
    final affected = await Database.instance.execute(
      '''UPDATE vehicles SET plate_number=?, vin=?, brand=?, model=?, year=?, color=?, owner_name=?, owner_phone=?, photo_url=?, inspection_date=?, insurance_date=?
         WHERE id=? AND deleted_at IS NULL''',
      [
        plateNumber,
        body['vin'],
        body['brand'],
        body['model'],
        body['year'],
        body['color'],
        body['owner_name'],
        body['owner_phone'],
        body['photo_url'],
        body['inspection_date'],
        body['insurance_date'],
        vehicleId,
      ],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    final results = await Database.instance.query(
      'SELECT * FROM vehicles WHERE id = ?',
      [vehicleId],
    );
    return Response.ok(jsonEncode(_toJson(results.first)));
  }

  static Future<Response> delete(Request request, String id) async {
    final vehicleId = int.parse(id);
    final affected = await Database.instance.execute(
      'UPDATE vehicles SET deleted_at = NOW() WHERE id = ? AND deleted_at IS NULL',
      [vehicleId],
    );
    if (affected == 0) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode({'success': true}));
  }

  static Map<String, dynamic> _toJson(dynamic r) => {
    'id': r['id'],
    'plate_number': r['plate_number']?.toString(),
    'vin': r['vin']?.toString(),
    'brand': r['brand']?.toString(),
    'model': r['model']?.toString(),
    'year': r['year'],
    'color': r['color']?.toString(),
    'owner_name': r['owner_name']?.toString(),
    'owner_phone': r['owner_phone']?.toString(),
    'photo_url': r['photo_url']?.toString(),
    'inspection_date': _fmt(r['inspection_date']),
    'insurance_date': _fmt(r['insurance_date']),
    'record_count': r['record_count'],
    'total_cost': r['total_cost'],
    'last_record_date': _fmt(r['last_record_date']),
    'created_at': r['created_at']?.toString(),
    'updated_at': r['updated_at']?.toString(),
  };

  static String _fmt(dynamic v) => v?.toString().split(' ').first ?? '';
}
