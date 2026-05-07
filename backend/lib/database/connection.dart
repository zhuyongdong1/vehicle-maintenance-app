import 'package:mysql1/mysql1.dart';
import '../config.dart';

class Database {
  static Database? _instance;
  MySqlConnection? _connection;

  Database._();

  static Database get instance {
    _instance ??= Database._();
    return _instance!;
  }

  Future<void> initialize() async {
    try {
      final settings = ConnectionSettings(
        host: AppConfig.dbHost,
        port: AppConfig.dbPort,
        user: AppConfig.dbUser,
        password: AppConfig.dbPassword,
        db: AppConfig.dbName,
      );
      _connection = await MySqlConnection.connect(settings);
      await _connection!.query('SET NAMES utf8mb4');
      if (AppConfig.runSchemaMigrations) {
        await _ensureSchemaUpdates();
      }
      print('MySQL connected successfully');
    } catch (e, st) {
      _connection = null;
      print('MySQL connection failed: $e\n$st');
      rethrow;
    }
  }

  Future<Results> query(String sql, [List<Object?>? params]) async {
    if (_connection == null) throw Exception('Database not connected');
    return await _connection!.query(sql, params);
  }

  Future<int> insert(String sql, [List<Object?>? params]) async {
    if (_connection == null) throw Exception('Database not connected');
    final result = await _connection!.query(sql, params);
    return result.insertId ?? 0;
  }

  Future<int> execute(String sql, [List<Object?>? params]) async {
    if (_connection == null) throw Exception('Database not connected');
    final result = await _connection!.query(sql, params);
    return result.affectedRows ?? 0;
  }

  Future<void> _ensureSchemaUpdates() async {
    await _addColumnIfMissing(
      'records',
      'purchase_cost',
      'ALTER TABLE records ADD COLUMN purchase_cost DECIMAL(10,2) NULL COMMENT "进价合计" AFTER cost',
    );
    await _addColumnIfMissing(
      'records',
      'fee_items',
      'ALTER TABLE records ADD COLUMN fee_items TEXT NULL COMMENT "费用明细JSON" AFTER parts',
    );
    await _addColumnIfMissing(
      'records',
      'status',
      'ALTER TABLE records ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT "pending" COMMENT "工单状态: pending/repairing/completed/settled" AFTER category_id',
    );
    await _createInventoryTablesIfMissing();
  }

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String alterSql,
  ) async {
    if (_connection == null) throw Exception('Database not connected');
    var exists = false;
    try {
      exists = await _columnExists(table, column);
    } catch (e) {
      print('Column existence check failed for $table.$column: $e');
    }
    if (!exists) {
      try {
        await _connection!.query(alterSql);
      } catch (e) {
        if (!e.toString().contains('Duplicate column name')) {
          rethrow;
        }
      }
    }
  }

  Future<bool> _columnExists(String table, String column) async {
    if (_connection == null) throw Exception('Database not connected');
    final tableName = _sqlLiteral(table);
    final columnName = _sqlLiteral(column);
    final columns = await _connection!.query('''
      SELECT COUNT(*) as count
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = '$tableName'
        AND COLUMN_NAME = '$columnName'
      ''');
    if (columns.isEmpty) return false;
    final count = columns.first['count'];
    return int.tryParse(count.toString()) != 0;
  }

  String _sqlLiteral(String value) => value.replaceAll("'", "''");

  Future<void> _createInventoryTablesIfMissing() async {
    if (_connection == null) throw Exception('Database not connected');
    await _connection!.query('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        category VARCHAR(50),
        sku VARCHAR(50),
        unit VARCHAR(20) DEFAULT '件',
        stock_quantity INT NOT NULL DEFAULT 0,
        warning_quantity INT NOT NULL DEFAULT 5,
        purchase_price DECIMAL(10,2) DEFAULT 0,
        sale_price DECIMAL(10,2) DEFAULT 0,
        supplier VARCHAR(100),
        location VARCHAR(100),
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uk_inventory_sku (sku)
      )
    ''');
    await _connection!.query('''
      CREATE TABLE IF NOT EXISTS inventory_transactions (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        item_id BIGINT NOT NULL,
        type ENUM('in', 'out', 'adjust') NOT NULL,
        quantity INT NOT NULL,
        unit_price DECIMAL(10,2) DEFAULT 0,
        related_record_id INT,
        operator VARCHAR(50),
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (item_id) REFERENCES inventory_items(id) ON DELETE CASCADE,
        FOREIGN KEY (related_record_id) REFERENCES records(id) ON DELETE SET NULL
      )
    ''');
    await _addColumnIfMissing(
      'inventory_items',
      'stock_quantity',
      'ALTER TABLE inventory_items ADD COLUMN stock_quantity INT NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      'inventory_items',
      'warning_quantity',
      'ALTER TABLE inventory_items ADD COLUMN warning_quantity INT NOT NULL DEFAULT 5',
    );
    await _addColumnIfMissing(
      'inventory_items',
      'purchase_price',
      'ALTER TABLE inventory_items ADD COLUMN purchase_price DECIMAL(10,2) DEFAULT 0',
    );
    await _addColumnIfMissing(
      'inventory_items',
      'sale_price',
      'ALTER TABLE inventory_items ADD COLUMN sale_price DECIMAL(10,2) DEFAULT 0',
    );
    await _addColumnIfMissing(
      'inventory_items',
      'supplier',
      'ALTER TABLE inventory_items ADD COLUMN supplier VARCHAR(100)',
    );
    await _addColumnIfMissing(
      'inventory_items',
      'location',
      'ALTER TABLE inventory_items ADD COLUMN location VARCHAR(100)',
    );
    await _addColumnIfMissing(
      'inventory_items',
      'notes',
      'ALTER TABLE inventory_items ADD COLUMN notes TEXT',
    );
    if (await _columnExists('inventory_items', 'stock_qty')) {
      await _connection!.query('''
        UPDATE inventory_items
        SET stock_quantity = CAST(stock_qty AS SIGNED)
        WHERE stock_quantity = 0 AND stock_qty IS NOT NULL
      ''');
    }
    if (await _columnExists('inventory_items', 'purchase_price_cent')) {
      await _connection!.query('''
        UPDATE inventory_items
        SET purchase_price = purchase_price_cent / 100
        WHERE purchase_price = 0 AND purchase_price_cent IS NOT NULL
      ''');
    }
    if (await _columnExists('inventory_items', 'sale_price_cent')) {
      await _connection!.query('''
        UPDATE inventory_items
        SET sale_price = sale_price_cent / 100
        WHERE sale_price = 0 AND sale_price_cent IS NOT NULL
      ''');
    }
  }
}
