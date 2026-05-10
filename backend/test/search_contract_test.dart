import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('vehicle list search supports the fields promised by the UI', () {
    final source = File('lib/handlers/vehicle_handler.dart').readAsStringSync();

    expect(source, contains('v.plate_number LIKE ?'));
    expect(source, contains('v.vin LIKE ?'));
    expect(source, contains('v.owner_name LIKE ?'));
    expect(source, contains('v.owner_phone LIKE ?'));
  });

  test('record list search supports the fields promised by the UI', () {
    final source = File('lib/handlers/record_handler.dart').readAsStringSync();

    expect(source, contains('v.plate_number LIKE ?'));
    expect(source, contains('r.items LIKE ?'));
    expect(source, contains('r.workshop LIKE ?'));
  });
}
