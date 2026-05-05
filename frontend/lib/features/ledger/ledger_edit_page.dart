import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/category.dart';
import '../../core/theme.dart';
import '../../core/api/ledger_api.dart';
import '../../core/api/category_api.dart';

class LedgerEditPage extends StatefulWidget {
  final int ledgerId;
  const LedgerEditPage({super.key, required this.ledgerId});

  @override
  State<LedgerEditPage> createState() => _LedgerEditPageState();
}

class _LedgerEditPageState extends State<LedgerEditPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'expense';
  String _recordDate = '';
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _saving = false;
  bool _loading = true;

  final _api = LedgerApi();
  final _categoryApi = CategoryApi();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadCategories() async {
    try {
      _categories = await _categoryApi.getList(
        _type == 'income' ? 'ledger_income' : 'ledger_expense',
      );
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final item = await _api.getById(widget.ledgerId);
      _type = item.type;
      _amountController.text = item.amount.toString();
      _recordDate = item.recordDate;
      _descriptionController.text = item.description ?? '';
      await _loadCategories();
      _selectedCategory = _categories.cast<Category?>().firstWhere(
        (c) => c?.id == item.categoryId,
        orElse: () => null,
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入金额')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.update(widget.ledgerId, ledgerFromForm());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存成功')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
    setState(() => _saving = false);
  }

  dynamic ledgerFromForm() {
    // Return map for API compatibility
    return {
      'type': _type,
      'category_id': _selectedCategory?.id,
      'amount': double.tryParse(_amountController.text) ?? 0,
      'record_date': _recordDate,
      'description': _descriptionController.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑记账')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isIncome = _type == 'income';
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑记账'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              '保存',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = 'income';
                        _selectedCategory = null;
                      });
                      _loadCategories();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: isIncome
                          ? BoxDecoration(
                              color: AppTheme.income,
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: Center(
                        child: Text(
                          '收入',
                          style: TextStyle(
                            color: isIncome
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = 'expense';
                        _selectedCategory = null;
                      });
                      _loadCategories();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: !isIncome
                          ? BoxDecoration(
                              color: AppTheme.expense,
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: Center(
                        child: Text(
                          '支出',
                          style: TextStyle(
                            color: !isIncome
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '分类'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Category>(
                  value: _selectedCategory,
                  isExpanded: true,
                  hint: const Text(
                    '选择分类',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '金额 *',
              prefixText: '¥',
            ),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _recordDate = _format(d));
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '日期 *',
                suffixIcon: Icon(Icons.calendar_today_rounded, size: 20),
              ),
              child: Text(_recordDate, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: '说明', hintText: '选填'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
