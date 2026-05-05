class InventoryItem {
  final int? id;
  final String name;
  final String? category;
  final String? sku;
  final String unit;
  final int stockQuantity;
  final int warningQuantity;
  final double purchasePrice;
  final double salePrice;
  final String? supplier;
  final String? location;
  final String? notes;
  final int totalIn;
  final int totalOut;
  final String? createdAt;
  final String? updatedAt;

  InventoryItem({
    this.id,
    required this.name,
    this.category,
    this.sku,
    this.unit = '件',
    this.stockQuantity = 0,
    this.warningQuantity = 5,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.supplier,
    this.location,
    this.notes,
    this.totalIn = 0,
    this.totalOut = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'],
    name: json['name'] ?? '',
    category: json['category'],
    sku: json['sku'],
    unit: json['unit'] ?? '件',
    stockQuantity: _intValue(json['stock_quantity']),
    warningQuantity: _intValue(json['warning_quantity'], fallback: 5),
    purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0,
    salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0,
    supplier: json['supplier'],
    location: json['location'],
    notes: json['notes'],
    totalIn: _intValue(json['total_in']),
    totalOut: _intValue(json['total_out']),
    createdAt: json['created_at'],
    updatedAt: json['updated_at'],
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'sku': sku,
    'unit': unit,
    'stock_quantity': stockQuantity,
    'warning_quantity': warningQuantity,
    'purchase_price': purchasePrice,
    'sale_price': salePrice,
    'supplier': supplier,
    'location': location,
    'notes': notes,
  };

  bool get isLowStock => stockQuantity <= warningQuantity;
}

class InventoryTransaction {
  final int? id;
  final int itemId;
  final String? itemName;
  final String? itemSku;
  final String type;
  final int quantity;
  final double unitPrice;
  final int? relatedRecordId;
  final String? relatedRecordInfo;
  final String? operator;
  final String? notes;
  final String? createdAt;

  InventoryTransaction({
    this.id,
    required this.itemId,
    this.itemName,
    this.itemSku,
    required this.type,
    required this.quantity,
    this.unitPrice = 0,
    this.relatedRecordId,
    this.relatedRecordInfo,
    this.operator,
    this.notes,
    this.createdAt,
  });

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) =>
      InventoryTransaction(
        id: json['id'],
        itemId: json['item_id'] ?? 0,
        itemName: json['item_name'],
        itemSku: json['item_sku'],
        type: json['type'] ?? 'in',
        quantity: _intValue(json['quantity']),
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
        relatedRecordId: json['related_record_id'],
        relatedRecordInfo: json['related_record_info'],
        operator: json['operator'],
        notes: json['notes'],
        createdAt: json['created_at'],
      );
}

class InventoryStats {
  final int itemCount;
  final int stockCount;
  final double stockValue;
  final int warningCount;
  final List<Map<String, dynamic>> categories;
  final List<InventoryTransaction> recentTransactions;

  InventoryStats({
    required this.itemCount,
    required this.stockCount,
    required this.stockValue,
    required this.warningCount,
    required this.categories,
    required this.recentTransactions,
  });

  factory InventoryStats.fromJson(Map<String, dynamic> json) => InventoryStats(
    itemCount: _intValue(json['item_count']),
    stockCount: _intValue(json['stock_count']),
    stockValue: (json['stock_value'] as num?)?.toDouble() ?? 0,
    warningCount: _intValue(json['warning_count']),
    categories: List<Map<String, dynamic>>.from(json['categories'] ?? []),
    recentTransactions: (json['recent_transactions'] as List? ?? [])
        .map((e) => InventoryTransaction.fromJson(e))
        .toList(),
  );
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
