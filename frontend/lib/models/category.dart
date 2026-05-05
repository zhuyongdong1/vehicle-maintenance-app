class Category {
  final int? id;
  final String type; // 'maintenance_type', 'ledger_income', 'ledger_expense'
  final String name;
  final int sortOrder;
  final String? createdAt;

  Category({
    this.id,
    required this.type,
    required this.name,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'name': name,
      'sort_order': sortOrder,
    };
  }
}
