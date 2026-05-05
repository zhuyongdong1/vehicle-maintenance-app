import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('inventory transaction table is created after referenced tables', () {
    final schema = File('lib/database/schema.sql').readAsStringSync();

    final inventoryItemsIndex = schema.indexOf(
      'CREATE TABLE IF NOT EXISTS inventory_items',
    );
    final recordsIndex = schema.indexOf('CREATE TABLE IF NOT EXISTS records');
    final transactionsIndex = schema.indexOf(
      'CREATE TABLE IF NOT EXISTS inventory_transactions',
    );

    expect(inventoryItemsIndex, isNot(-1));
    expect(recordsIndex, isNot(-1));
    expect(transactionsIndex, isNot(-1));
    expect(inventoryItemsIndex, lessThan(transactionsIndex));
    expect(recordsIndex, lessThan(transactionsIndex));
  });
}
