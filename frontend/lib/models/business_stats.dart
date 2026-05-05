class BusinessStats {
  final double income;
  final double expense;
  final double profit;
  final int recordCount;
  final int vehicleCount;
  final double avgOrderAmount;
  final List<Map<String, dynamic>> trend;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> hotItems;

  BusinessStats({
    required this.income,
    required this.expense,
    required this.profit,
    required this.recordCount,
    required this.vehicleCount,
    required this.avgOrderAmount,
    required this.trend,
    required this.categories,
    required this.hotItems,
  });

  factory BusinessStats.fromJson(Map<String, dynamic> json) => BusinessStats(
    income: (json['income'] as num?)?.toDouble() ?? 0,
    expense: (json['expense'] as num?)?.toDouble() ?? 0,
    profit: (json['profit'] as num?)?.toDouble() ?? 0,
    recordCount: json['record_count'] ?? 0,
    vehicleCount: json['vehicle_count'] ?? 0,
    avgOrderAmount: (json['avg_order_amount'] as num?)?.toDouble() ?? 0,
    trend: List<Map<String, dynamic>>.from(json['trend'] ?? []),
    categories: List<Map<String, dynamic>>.from(json['categories'] ?? []),
    hotItems: List<Map<String, dynamic>>.from(json['hot_items'] ?? []),
  );
}
