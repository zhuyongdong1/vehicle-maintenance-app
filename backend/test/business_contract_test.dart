import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'record writes keep work orders and auto ledger entries in one transaction',
    () {
      final source = File(
        'lib/handlers/record_handler.dart',
      ).readAsStringSync();

      expect(source, contains('Database.instance.transaction'));
      expect(source, contains('_syncLedgerEntries'));
      expect(source, isNot(contains('Auto ledger creation failed')));
    },
  );

  test('record delete keeps financial records but removes dangling links', () {
    final source = File('lib/handlers/record_handler.dart').readAsStringSync();

    expect(source, contains('UPDATE ledger SET related_record_id = NULL'));
  });

  test('ledger settlement marks linked work order as settled', () {
    final source = File('lib/handlers/ledger_handler.dart').readAsStringSync();

    expect(source, contains("body['type'] == 'income'"));
    expect(source, contains("UPDATE records SET status = ?"));
    expect(source, contains("'settled'"));
  });

  test('record settlement creates income ledger directly', () {
    final router = File('lib/router.dart').readAsStringSync();
    final source = File('lib/handlers/record_handler.dart').readAsStringSync();

    expect(router, contains("router.post('/api/records/<id>/settle'"));
    expect(source, contains('static Future<Response> settle'));
    expect(source, contains("type: 'income'"));
  });

  test('vehicle delete is soft delete to preserve work order history', () {
    final source = File('lib/handlers/vehicle_handler.dart').readAsStringSync();

    expect(source, contains('deleted_at IS NULL'));
    expect(source, contains('UPDATE vehicles SET deleted_at = NOW()'));
    expect(source, isNot(contains('DELETE FROM vehicles')));
  });

  test('manual stock edits create an adjustment transaction', () {
    final source = File(
      'lib/handlers/inventory_handler.dart',
    ).readAsStringSync();

    expect(source, contains("VALUES (?, 'adjust', ?, ?, NULL, ?, ?)"));
    expect(source, contains('库存校准'));
  });
}
