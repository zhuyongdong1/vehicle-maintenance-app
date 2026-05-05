class DashboardStats {
  final double monthIncome;
  final double monthExpense;
  final double monthProfit;
  final int monthRecordCount;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> recentRecords;
  final List<Map<String, dynamic>> recentLedger;

  DashboardStats({
    required this.monthIncome,
    required this.monthExpense,
    required this.monthProfit,
    required this.monthRecordCount,
    required this.reminders,
    required this.recentRecords,
    required this.recentLedger,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      monthIncome: (json['month_income'] as num?)?.toDouble() ?? 0,
      monthExpense: (json['month_expense'] as num?)?.toDouble() ?? 0,
      monthProfit: (json['month_profit'] as num?)?.toDouble() ?? 0,
      monthRecordCount: json['month_record_count'] ?? 0,
      reminders: List<Map<String, dynamic>>.from(json['reminders'] ?? []),
      recentRecords: List<Map<String, dynamic>>.from(
        json['recent_records'] ?? [],
      ),
      recentLedger: List<Map<String, dynamic>>.from(
        json['recent_ledger'] ?? [],
      ),
    );
  }
}
