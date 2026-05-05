import 'package:shelf/shelf.dart';
import '../database/connection.dart';

class ExportHandler {
  static Future<Response> exportCsv(Request request) async {
    final csv = StringBuffer();

    csv.writeln('类型,日期,车牌号,项目/说明,分类,进价,售价,金额,里程,维修厂,备注');

    final results = await Database.instance.query('''
      SELECT '维修' as record_type, r.record_date, v.plate_number, r.items, c.name as category,
        r.purchase_cost, r.cost as sale_amount, r.cost as amount, r.mileage, r.workshop, r.notes
      FROM records r
      LEFT JOIN vehicles v ON r.vehicle_id = v.id
      LEFT JOIN categories c ON r.category_id = c.id
      UNION ALL
      SELECT CASE WHEN l.type='income' THEN '收入' ELSE '支出' END, l.record_date, '', l.description, lc.name,
        NULL, NULL, l.amount, NULL, '', ''
      FROM ledger l
      LEFT JOIN categories lc ON l.category_id = lc.id
      ORDER BY record_date DESC
    ''');

    for (final r in results) {
      final row = [
        r['record_type']?.toString() ?? '',
        r['record_date']?.toString() ?? '',
        _escapeCsv(r['plate_number']?.toString() ?? ''),
        _escapeCsv(r['items']?.toString() ?? ''),
        _escapeCsv(r['category']?.toString() ?? ''),
        r['purchase_cost']?.toString() ?? '',
        r['sale_amount']?.toString() ?? '',
        r['amount']?.toString() ?? '',
        r['mileage']?.toString() ?? '',
        _escapeCsv(r['workshop']?.toString() ?? ''),
        _escapeCsv(r['notes']?.toString() ?? ''),
      ];
      csv.writeln(row.join(','));
    }

    return Response.ok(
      csv.toString(),
      headers: {
        'Content-Type': 'text/csv; charset=utf-8',
        'Content-Disposition':
            'attachment; filename=export_${DateTime.now().toIso8601String().substring(0, 10)}.csv',
      },
    );
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
