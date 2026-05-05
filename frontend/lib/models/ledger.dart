class Ledger {
  final int? id;
  final String type; // 'income' or 'expense'
  final int? categoryId;
  final String? categoryName;
  final double amount;
  final String recordDate;
  final String? description;
  final int? relatedRecordId;
  final String? relatedRecordInfo;
  final String? createdAt;
  final String? updatedAt;

  Ledger({
    this.id,
    required this.type,
    this.categoryId,
    this.categoryName,
    required this.amount,
    required this.recordDate,
    this.description,
    this.relatedRecordId,
    this.relatedRecordInfo,
    this.createdAt,
    this.updatedAt,
  });

  factory Ledger.fromJson(Map<String, dynamic> json) {
    return Ledger(
      id: json['id'],
      type: json['type'] ?? 'expense',
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      amount: (json['amount'] as num).toDouble(),
      recordDate: json['record_date'] ?? '',
      description: json['description'],
      relatedRecordId: json['related_record_id'],
      relatedRecordInfo: json['related_record_info'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'category_id': categoryId,
      'amount': amount,
      'record_date': recordDate,
      'description': description,
      'related_record_id': relatedRecordId,
    };
  }
}
