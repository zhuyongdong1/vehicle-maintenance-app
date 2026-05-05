import 'dart:convert';

class RecordFeeItem {
  final String item;
  final double? purchasePrice;
  final double? salePrice;

  RecordFeeItem({required this.item, this.purchasePrice, this.salePrice});

  factory RecordFeeItem.fromJson(Map<String, dynamic> json) {
    return RecordFeeItem(
      item: json['item']?.toString() ?? '',
      purchasePrice: json['purchase_price'] != null
          ? (json['purchase_price'] as num).toDouble()
          : null,
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'item': item,
    'purchase_price': purchasePrice,
    'sale_price': salePrice,
  };
}

class Record {
  final int? id;
  final int vehicleId;
  final int? categoryId;
  final String? categoryName;
  final String? items;
  final double? cost;
  final double? purchaseCost;
  final int? mileage;
  final String recordDate;
  final String? workshop;
  final String? notes;
  final String? parts;
  final List<RecordFeeItem> feeItems;
  final String? reminderDate;
  final int? reminderMileage;
  final String? createdAt;
  final String? updatedAt;
  final String? plateNumber;
  final String? vehicleInfo;

  Record({
    this.id,
    required this.vehicleId,
    this.categoryId,
    this.categoryName,
    this.items,
    this.cost,
    this.purchaseCost,
    this.mileage,
    required this.recordDate,
    this.workshop,
    this.notes,
    this.parts,
    this.feeItems = const [],
    this.reminderDate,
    this.reminderMileage,
    this.createdAt,
    this.updatedAt,
    this.plateNumber,
    this.vehicleInfo,
  });

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'],
      vehicleId: json['vehicle_id'] ?? 0,
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      items: json['items'],
      cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      purchaseCost: json['purchase_cost'] != null
          ? (json['purchase_cost'] as num).toDouble()
          : null,
      mileage: json['mileage'],
      recordDate: json['record_date'] ?? '',
      workshop: json['workshop'],
      notes: json['notes'],
      parts: json['parts'],
      feeItems: _parseFeeItems(json['fee_items']),
      reminderDate: json['reminder_date'],
      reminderMileage: json['reminder_mileage'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      plateNumber: json['plate_number'],
      vehicleInfo: json['vehicle_info'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'category_id': categoryId,
      'items': items,
      'cost': cost,
      'purchase_cost': purchaseCost,
      'mileage': mileage,
      'record_date': recordDate,
      'workshop': workshop,
      'notes': notes,
      'parts': parts,
      'fee_items': feeItems.map((item) => item.toJson()).toList(),
      'reminder_date': reminderDate,
      'reminder_mileage': reminderMileage,
    };
  }

  static List<RecordFeeItem> _parseFeeItems(dynamic value) {
    if (value == null) return const [];
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => RecordFeeItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
