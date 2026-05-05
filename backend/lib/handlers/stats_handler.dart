import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../database/connection.dart';

class StatsHandler {
  static Future<Response> getOverview(Request request) async {
    try {
      final params = request.url.queryParameters;
      final days = int.tryParse(params['days'] ?? '30') ?? 30;
      final safeDays = days.clamp(7, 365);

      final summary = await Database.instance.query(
        '''
        SELECT
          COALESCE(SUM(CASE WHEN l.type='income' THEN l.amount ELSE 0 END), 0) as income,
          COALESCE(SUM(CASE WHEN l.type='expense' THEN l.amount ELSE 0 END), 0) as expense,
          COUNT(DISTINCT r.id) as record_count,
          COUNT(DISTINCT v.id) as vehicle_count
        FROM ledger l
        LEFT JOIN records r ON r.id = l.related_record_id
        LEFT JOIN vehicles v ON v.id = r.vehicle_id
        WHERE l.record_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
      ''',
        [safeDays],
      );

      final recordCountRes = await Database.instance.query(
        'SELECT COUNT(*) as cnt FROM records WHERE record_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)',
        [safeDays],
      );

      final trend = await Database.instance.query(
        '''
        SELECT DATE(record_date) as day,
          COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) as income,
          COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) as expense
        FROM ledger
        WHERE record_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        GROUP BY DATE(record_date)
        ORDER BY day ASC
      ''',
        [safeDays],
      );

      final categories = await Database.instance.query(
        '''
        SELECT COALESCE(c.name, '未分类') as category_name, COUNT(r.id) as record_count,
          COALESCE(SUM(r.cost), 0) as income
        FROM records r
        LEFT JOIN categories c ON r.category_id = c.id
        WHERE r.record_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        GROUP BY COALESCE(c.name, '未分类')
        ORDER BY income DESC
        LIMIT 8
      ''',
        [safeDays],
      );

      final hotItems = await Database.instance.query(
        '''
        SELECT COALESCE(c.name, r.items, '维修项目') as item_name,
          COUNT(*) as count,
          COALESCE(SUM(r.cost), 0) as income
        FROM records r
        LEFT JOIN categories c ON r.category_id = c.id
        WHERE r.record_date >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        GROUP BY COALESCE(c.name, r.items, '维修项目')
        ORDER BY count DESC, income DESC
        LIMIT 8
      ''',
        [safeDays],
      );

      final s = summary.first;
      final income = _double(s['income']);
      final expense = _double(s['expense']);
      final recordCount = recordCountRes.first['cnt'] ?? 0;
      final avgOrder = recordCount == 0 ? 0 : income / recordCount;

      return Response.ok(
        jsonEncode({
          'income': income,
          'expense': expense,
          'profit': income - expense,
          'record_count': recordCount,
          'vehicle_count': s['vehicle_count'] ?? 0,
          'avg_order_amount': avgOrder,
          'trend': trend
              .map(
                (r) => {
                  'date': r['day']?.toString().split(' ').first,
                  'income': _double(r['income']),
                  'expense': _double(r['expense']),
                },
              )
              .toList(),
          'categories': categories
              .map(
                (r) => {
                  'name': r['category_name']?.toString(),
                  'record_count': r['record_count'] ?? 0,
                  'income': _double(r['income']),
                },
              )
              .toList(),
          'hot_items': hotItems
              .map(
                (r) => {
                  'name': r['item_name']?.toString(),
                  'count': r['count'] ?? 0,
                  'income': _double(r['income']),
                },
              )
              .toList(),
        }),
      );
    } catch (e, st) {
      print('StatsHandler.getOverview error: $e\n$st');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  static double _double(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;
}
