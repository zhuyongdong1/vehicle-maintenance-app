import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/category_api.dart';
import '../../core/api/vehicle_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/category.dart';
import '../../models/record.dart';
import '../../models/vehicle.dart';

class RecordAddPage extends StatefulWidget {
  final int? vehicleId;
  const RecordAddPage({super.key, this.vehicleId});

  @override
  State<RecordAddPage> createState() => _RecordAddPageState();
}

class _RecordAddPageState extends State<RecordAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemsController = TextEditingController();
  final _mileageController = TextEditingController();
  final _workshopController = TextEditingController();
  final _notesController = TextEditingController();
  final _reminderMileageController = TextEditingController();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final List<_FeeRowControllers> _feeRows = [_FeeRowControllers()];

  final _vehicleApi = VehicleApi();
  final _categoryApi = CategoryApi();

  List<Vehicle> _vehicles = [];
  List<Category> _categories = [];
  Vehicle? _selectedVehicle;
  Category? _selectedCategory;
  String _recordDate = '';
  String? _reminderDate;
  bool _createLedger = true;
  bool _useExistingVehicle = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recordDate = _format(DateTime.now());
    _useExistingVehicle = widget.vehicleId != null;
    _loadVehicles();
    _loadCategories();
  }

  Future<void> _loadVehicles() async {
    try {
      _vehicles = await _vehicleApi.getList();
      if (widget.vehicleId != null && _vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => _vehicles.first,
        );
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await _categoryApi.getList('maintenance_type');
      if (mounted) setState(() {});
    } catch (_) {}
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_feeItems.isEmpty || _saleTotal <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写费用明细和售价')));
      return;
    }
    setState(() => _saving = true);
    try {
      final vehicle = await _resolveVehicleForRecord();
      if (vehicle == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final feeItems = _feeItems;
      await apiClientProvider.post(
        '/records',
        data: {
          'vehicle_id': vehicle.id,
          'category_id': _selectedCategory?.id,
          'items': _itemsController.text,
          'cost': _saleTotal,
          'purchase_cost': _purchaseTotal,
          'mileage': int.tryParse(_mileageController.text),
          'record_date': _recordDate,
          'workshop': _workshopController.text,
          'notes': _notesController.text,
          'parts': feeItems.map((item) => item.item).join('、'),
          'fee_items': feeItems.map((item) => item.toJson()).toList(),
          'reminder_date': _reminderDate,
          'reminder_mileage': int.tryParse(_reminderMileageController.text),
          if (_createLedger) 'create_ledger': true,
        },
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

  Future<Vehicle?> _resolveVehicleForRecord() async {
    if (_useExistingVehicle) {
      if (_selectedVehicle == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请选择车辆')));
        return null;
      }
      return _selectedVehicle;
    }

    final plateNumber = _plateController.text.trim();
    final existingVehicle = _findExistingVehicleByPlate(plateNumber);
    if (existingVehicle != null) {
      _selectedVehicle = existingVehicle;
      return existingVehicle;
    }

    final vehicle = await _vehicleApi.create(
      Vehicle(
        plateNumber: plateNumber,
        vin: _emptyToNull(_vinController.text),
        brand: _emptyToNull(_brandController.text),
        model: _emptyToNull(_modelController.text),
        ownerName: _emptyToNull(_ownerNameController.text),
        ownerPhone: _emptyToNull(_ownerPhoneController.text),
      ),
    );
    _vehicles = [vehicle, ..._vehicles];
    _selectedVehicle = vehicle;
    return vehicle;
  }

  Vehicle? _findExistingVehicleByPlate(String plateNumber) {
    final normalizedPlate = plateNumber.toUpperCase();
    for (final vehicle in _vehicles) {
      if (vehicle.plateNumber.trim().toUpperCase() == normalizedPlate) {
        return vehicle;
      }
    }
    return null;
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('接车开单')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            _buildStepHeader(),
            const SizedBox(height: 18),
            const SectionHeader(title: '车辆信息', subtitle: '先确认车辆，减少后续录入错误'),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: _buildVehicleSection(),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '维修项目', subtitle: '记录项目、分类、日期和工时场地'),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCategorySelector(),
                  _field('维修项目 *', _itemsController, hint: '例如：更换机油、四轮定位'),
                  _dateField('维修日期 *', _recordDate, () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setState(() => _recordDate = _format(d));
                  }),
                  _field('维修厂 / 技师', _workshopController, hint: '选填'),
                  _field(
                    '当前里程(km)',
                    _mileageController,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '费用与配件', subtitle: '售价生成收入，进价生成支出'),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: _buildFeeTable(),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '维修照片', subtitle: '用于交车确认和售后追溯'),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('当前版本未接入工单照片字段'))),
                child: Container(
                  height: 118,
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SoftIcon(
                          icon: Icons.add_a_photo_rounded,
                          color: AppTheme.primary,
                          size: 48,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '添加维修过程照片',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '下次保养提醒', subtitle: '交车前设置回访和到期提醒'),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _dateField('提醒日期', _reminderDate, () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(
                        const Duration(days: 180),
                      ),
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
                  _field('备注', _notesController, maxLines: 3),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimary.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? '正在保存' : '保存工单'),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader() {
    return AppSurfaceCard(
      radius: AppRadius.large,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SoftIcon(
            icon: Icons.assignment_add,
            color: AppTheme.primary,
            size: 50,
            iconSize: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '新建维修工单',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '按接车、维修、结算、提醒顺序完成录入',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '关联车辆 *',
        prefixIcon: Icon(Icons.directions_car_rounded),
      ),
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
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedVehicle = v),
        ),
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.add_rounded),
                label: Text('新录车辆'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.folder_shared_rounded),
                label: Text('选择已有'),
              ),
            ],
            selected: {_useExistingVehicle},
            onSelectionChanged: (value) {
              setState(() => _useExistingVehicle = value.first);
            },
          ),
        ),
        const SizedBox(height: 14),
        if (_useExistingVehicle)
          _buildVehicleSelector()
        else
          _buildInlineVehicleFields(),
      ],
    );
  }

  Widget _buildInlineVehicleFields() {
    return Column(
      children: [
        _field('车牌号 *', _plateController, hint: '例如：沪A12345'),
        _field('车主姓名', _ownerNameController),
        _field(
          '联系电话',
          _ownerPhoneController,
          keyboardType: TextInputType.phone,
        ),
        Row(
          children: [
            Expanded(child: _field('品牌', _brandController)),
            const SizedBox(width: 10),
            Expanded(child: _field('车型', _modelController)),
          ],
        ),
        _field('VIN / 车架号', _vinController),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '维修分类',
          prefixIcon: Icon(Icons.category_rounded),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Category>(
            value: _selectedCategory,
            isExpanded: true,
            hint: const Text(
              '选择分类',
              style: TextStyle(color: AppTheme.textHint),
            ),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          hintText: hint,
        ),
        validator: label.contains('*')
            ? (v) => (v == null || v.trim().isEmpty) ? '请填写$label' : null
            : null,
      ),
    );
  }

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
            const SizedBox(width: 10),
            Expanded(
              child: _FeeTotal(label: '售价合计', value: _saleTotal),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '同步生成收支流水',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('保存工单后自动写入维修收入和成本支出'),
          value: _createLedger,
          onChanged: (v) => setState(() => _createLedger = v),
          activeTrackColor: AppTheme.primary,
        ),
      ],
    );
  }

  Widget _buildFeeRow(int index) {
    final row = _feeRows[index];
    final canDelete = _feeRows.length > 1;
    return Container(
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
              const SizedBox(width: 4),
              IconButton(
                tooltip: '删除',
                onPressed: canDelete
                    ? () => setState(() => _feeRows.removeAt(index).dispose())
                    : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, String? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _itemsController.dispose();
    _mileageController.dispose();
    _workshopController.dispose();
    _notesController.dispose();
    _reminderMileageController.dispose();
    _plateController.dispose();
    _vinController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
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

  RecordFeeItem toFeeItem() {
    return RecordFeeItem(
      item: item.text.trim(),
      quantity: _quantityValue(quantity.text),
      purchasePrice: double.tryParse(purchasePrice.text),
      salePrice: double.tryParse(salePrice.text),
    );
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
