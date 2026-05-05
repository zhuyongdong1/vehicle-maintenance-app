import 'package:flutter/material.dart';
import '../../models/ledger.dart';
import '../../core/theme.dart';
import '../../core/api/ledger_api.dart';

class LedgerDetailPage extends StatefulWidget {
  final int ledgerId;
  const LedgerDetailPage({super.key, required this.ledgerId});

  @override
  State<LedgerDetailPage> createState() => _LedgerDetailPageState();
}

class _LedgerDetailPageState extends State<LedgerDetailPage> {
  final _api = LedgerApi();
  Ledger? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _item = await _api.getById(widget.ledgerId);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('记账详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final item = _item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('记账详情')),
        body: const Center(child: Text('未找到记录')),
      );
    }

    final isIncome = item.type == 'income';
    return Scaffold(
      appBar: AppBar(title: Text('${isIncome ? "收入" : "支出"}详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '${isIncome ? "+" : "-"}¥${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? AppTheme.income : AppTheme.expense,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _row('类型', isIncome ? '收入' : '支出'),
                  _row('分类', item.categoryName ?? '-'),
                  _row('日期', item.recordDate),
                  if (item.description != null && item.description!.isNotEmpty)
                    _row('说明', item.description!),
                  if (item.relatedRecordInfo != null &&
                      item.relatedRecordInfo!.isNotEmpty)
                    _row('关联维修', item.relatedRecordInfo!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}
