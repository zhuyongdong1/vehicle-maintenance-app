import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/ledger.dart';
import '../../models/category.dart';
import '../../core/theme.dart';
import '../../core/api/ledger_api.dart';
import '../../core/api/category_api.dart';

class LedgerAddPage extends StatefulWidget {
  const LedgerAddPage({super.key});

  @override
  State<LedgerAddPage> createState() => _LedgerAddPageState();
}

class _LedgerAddPageState extends State<LedgerAddPage> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _recordDate = '';
  bool _saving = false;
  List<Category> _categories = [];
  Category? _selectedCategory;
  int? _relatedRecordId;
  bool _prefillApplied = false;
  String? _preferredCategoryName;

  final _api = LedgerApi();
  final _categoryApi = CategoryApi();

  @override
  void initState() {
    super.initState();
    _recordDate = _format(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefillApplied) return;
    _prefillApplied = true;
    final params = GoRouterState.of(context).uri.queryParameters;
    final type = params['type'];
    if (type == 'income' || type == 'expense') {
      _type = type!;
      _preferredCategoryName = type == 'income' ? '维修收入' : '配件采购';
    }
    final amount = params['amount'];
    if (amount != null && amount.isNotEmpty) {
      _amountController.text = amount;
    }
    final date = params['date'];
    if (date != null && date.isNotEmpty) {
      _recordDate = date;
    }
    final description = params['description'];
    if (description != null && description.isNotEmpty) {
      _descriptionController.text = description;
    }
    _relatedRecordId = int.tryParse(params['record_id'] ?? '');
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryApi.getList(
        _type == 'income' ? 'ledger_income' : 'ledger_expense',
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = _pickCategory(categories);
      });
    } catch (_) {}
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入金额')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.create(
        Ledger(
          type: _type,
          categoryId: _selectedCategory?.id,
          amount: double.parse(_amountController.text),
          recordDate: _recordDate,
          description: _descriptionController.text,
          relatedRecordId: _relatedRecordId,
        ),
      );
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
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == 'income';
    return Scaffold(
      appBar: AppBar(
        title: const Text('记一笔'),
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
                        _preferredCategoryName = '维修收入';
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
                        _preferredCategoryName = '配件采购';
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
            autofocus: true,
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

  Category? _pickCategory(List<Category> categories) {
    final preferred = _preferredCategoryName;
    if (preferred != null) {
      for (final category in categories) {
        if (category.name == preferred) return category;
      }
    }
    return categories.isEmpty ? null : categories.first;
  }
}
