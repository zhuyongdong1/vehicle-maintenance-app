import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/record.dart';
import '../../models/vehicle.dart';
import '../../models/category.dart';
import '../../core/theme.dart';
import '../../core/api/record_api.dart';
import '../../core/api/vehicle_api.dart';
import '../../core/api/category_api.dart';

class RecordEditPage extends StatefulWidget {
  final int recordId;
  const RecordEditPage({super.key, required this.recordId});

  @override
  State<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends State<RecordEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemsController = TextEditingController();
  final _mileageController = TextEditingController();
  final _workshopController = TextEditingController();
  final _notesController = TextEditingController();
  final _reminderMileageController = TextEditingController();
  final List<_FeeRowControllers> _feeRows = [_FeeRowControllers()];

  final _recordApi = RecordApi();
  final _vehicleApi = VehicleApi();
  final _categoryApi = CategoryApi();

  List<Vehicle> _vehicles = [];
  List<Category> _categories = [];
  Vehicle? _selectedVehicle;
  Category? _selectedCategory;
  String _recordDate = '';
  String? _reminderDate;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<RecordFeeItem> get _feeItems {
    return _feeRows
        .map((row) => row.toFeeItem())
        .where(
          (item) =>
              item.item.trim().isNotEmpty ||
              item.quantity > 1 ||
              (item.purchasePrice ?? 0) > 0 ||
              (item.salePrice ?? 0) > 0,
        )
        .toList();
  }

  double get _purchaseTotal =>
      _feeItems.fold(0, (sum, item) => sum + item.purchaseTotal);

  double get _saleTotal =>
      _feeItems.fold(0, (sum, item) => sum + item.saleTotal);

  double get _profitTotal => _saleTotal - _purchaseTotal;

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _recordApi.getById(widget.recordId),
        _vehicleApi.getList(),
        _categoryApi.getList('maintenance_type'),
      ]);
      final record = results[0] as Record;
      _vehicles = results[1] as List<Vehicle>;
      _categories = results[2] as List<Category>;

      _selectedVehicle = _vehicles.cast<Vehicle?>().firstWhere(
        (v) => v?.id == record.vehicleId,
        orElse: () => null,
      );
      _selectedCategory = _categories.cast<Category?>().firstWhere(
        (c) => c?.id == record.categoryId,
        orElse: () => null,
      );
      _itemsController.text = record.items ?? '';
      _mileageController.text = record.mileage?.toString() ?? '';
      _recordDate = record.recordDate;
      _workshopController.text = record.workshop ?? '';
      _notesController.text = record.notes ?? '';
      for (final row in _feeRows) {
        row.dispose();
      }
      _feeRows
        ..clear()
        ..addAll(
          record.feeItems.isNotEmpty
              ? record.feeItems.map(_FeeRowControllers.fromFeeItem)
              : [
                  _FeeRowControllers.fromFeeItem(
                    RecordFeeItem(
                      item: record.parts ?? record.items ?? '',
                      purchasePrice: record.purchaseCost,
                      salePrice: record.cost,
                    ),
                  ),
                ],
        );
      _reminderDate = record.reminderDate;
      _reminderMileageController.text =
          record.reminderMileage?.toString() ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择车辆')));
      return;
    }
    if (_feeItems.isEmpty || _saleTotal <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写费用明细和售价')));
      return;
    }
    setState(() => _saving = true);
    try {
      final feeItems = _feeItems;
      await _recordApi.update(
        widget.recordId,
        Record(
          vehicleId: _selectedVehicle!.id ?? 0,
          categoryId: _selectedCategory?.id,
          items: _itemsController.text,
          cost: _saleTotal,
          purchaseCost: _purchaseTotal,
          mileage: int.tryParse(_mileageController.text),
          recordDate: _recordDate,
          workshop: _workshopController.text,
          notes: _notesController.text,
          parts: feeItems.map((item) => item.item).join('、'),
          feeItems: feeItems,
          reminderDate: _reminderDate,
          reminderMileage: int.tryParse(_reminderMileageController.text),
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
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑维修')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑维修'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildVehicleSelector(),
            _buildCategorySelector(),
            _field('维修项目', _itemsController),
            const SizedBox(height: 2),
            const Text(
              '费用明细',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildFeeTable(),
            const SizedBox(height: 14),
            _field(
              '里程数(km)',
              _mileageController,
              keyboardType: TextInputType.number,
            ),
            _dateField('维修日期 *', _recordDate, () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _recordDate = _format(d));
            }),
            _field('维修厂', _workshopController),
            _field('备注', _notesController, maxLines: 3),
            const SizedBox(height: 16),
            const Text(
              '下次保养提醒',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _dateField('提醒日期', _reminderDate, () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 180)),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _reminderDate = _format(d));
            }),
            _field(
              '提醒里程(km)',
              _reminderMileageController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: InputDecorator(
      decoration: const InputDecoration(labelText: '关联车辆 *'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Vehicle>(
          value: _selectedVehicle,
          isExpanded: true,
          hint: const Text('选择车辆', style: TextStyle(color: AppTheme.textHint)),
          items: _vehicles
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(
                    '${v.plateNumber} · ${v.brand ?? ""} ${v.model ?? ""}',
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedVehicle = v),
        ),
      ),
    ),
  );

  Widget _buildCategorySelector() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: InputDecorator(
      decoration: const InputDecoration(labelText: '维修分类'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Category>(
          value: _selectedCategory,
          isExpanded: true,
          hint: const Text('选择分类', style: TextStyle(color: AppTheme.textHint)),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: c,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, prefixText: prefix),
    ),
  );

  Widget _buildFeeTable() {
    return Column(
      children: [
        for (var i = 0; i < _feeRows.length; i++) _buildFeeRow(i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _feeRows.add(_FeeRowControllers())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('添加项目'),
          ),
        ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: _FeeTotal(label: '进价合计', value: _purchaseTotal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeeTotal(label: '售价合计', value: _saleTotal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FeeTotal(label: '收益合计', value: _profitTotal),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeeRow(int index) {
    final row = _feeRows[index];
    final canDelete = _feeRows.length > 1;
    return Dismissible(
      key: ObjectKey(row),
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: const _SwipeDeleteBackground(),
      onDismissed: (_) {
        setState(() {
          final rowIndex = _feeRows.indexOf(row);
          if (rowIndex == -1) return;
          final removed = _feeRows.removeAt(rowIndex);
          removed.dispose();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: row.item,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(labelText: '项目 ${index + 1}'),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '数量'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row.purchasePrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '¥',
                      labelText: '进价',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: row.salePrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '¥',
                      labelText: '售价',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _FeeProfit(value: row.profit)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, String? value, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
        ),
        child: Text(
          value ?? '点击选择',
          style: TextStyle(
            color: value != null ? AppTheme.textPrimary : AppTheme.textHint,
            fontSize: 14,
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _itemsController.dispose();
    _mileageController.dispose();
    _workshopController.dispose();
    _notesController.dispose();
    _reminderMileageController.dispose();
    for (final row in _feeRows) {
      row.dispose();
    }
    super.dispose();
  }
}

class _FeeRowControllers {
  final item = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final purchasePrice = TextEditingController();
  final salePrice = TextEditingController();

  _FeeRowControllers();

  factory _FeeRowControllers.fromFeeItem(RecordFeeItem feeItem) {
    return _FeeRowControllers()
      ..item.text = feeItem.item
      ..quantity.text = feeItem.quantity.toString()
      ..purchasePrice.text = feeItem.purchasePrice?.toString() ?? ''
      ..salePrice.text = feeItem.salePrice?.toString() ?? '';
  }

  RecordFeeItem toFeeItem() {
    return RecordFeeItem(
      item: item.text.trim(),
      quantity: _quantityValue(quantity.text),
      purchasePrice: double.tryParse(purchasePrice.text),
      salePrice: double.tryParse(salePrice.text),
    );
  }

  double get profit {
    final purchase = double.tryParse(purchasePrice.text) ?? 0;
    final sale = double.tryParse(salePrice.text) ?? 0;
    return (sale - purchase) * _quantityValue(quantity.text);
  }

  void dispose() {
    item.dispose();
    quantity.dispose();
    purchasePrice.dispose();
    salePrice.dispose();
  }
}

int _quantityValue(String value) {
  final parsed = int.tryParse(value.trim()) ?? 1;
  return parsed <= 0 ? 1 : parsed;
}

class _FeeProfit extends StatelessWidget {
  final double value;

  const _FeeProfit({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value < 0 ? AppTheme.expense : AppTheme.success;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '收益',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥${value.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(right: 18),
      decoration: BoxDecoration(
        color: AppTheme.expense,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

class _FeeTotal extends StatelessWidget {
  final String label;
  final double value;

  const _FeeTotal({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${value.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
