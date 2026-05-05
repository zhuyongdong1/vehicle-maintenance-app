import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/vehicle.dart';
import '../../core/api/vehicle_api.dart';

class VehicleEditPage extends StatefulWidget {
  final int vehicleId;
  const VehicleEditPage({super.key, required this.vehicleId});

  @override
  State<VehicleEditPage> createState() => _VehicleEditPageState();
}

class _VehicleEditPageState extends State<VehicleEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  String? _inspectionDate;
  String? _insuranceDate;
  bool _saving = false;
  bool _loading = true;

  final _api = VehicleApi();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final v = await _api.getById(widget.vehicleId);
      setState(() {
        _plateController.text = v.plateNumber;
        _vinController.text = v.vin ?? '';
        _brandController.text = v.brand ?? '';
        _modelController.text = v.model ?? '';
        _yearController.text = v.year?.toString() ?? '';
        _colorController.text = v.color ?? '';
        _ownerNameController.text = v.ownerName ?? '';
        _ownerPhoneController.text = v.ownerPhone ?? '';
        _inspectionDate = v.inspectionDate;
        _insuranceDate = v.insuranceDate;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final vehicle = Vehicle(
        plateNumber: _plateController.text,
        vin: _vinController.text,
        brand: _brandController.text,
        model: _modelController.text,
        year: int.tryParse(_yearController.text),
        color: _colorController.text,
        ownerName: _ownerNameController.text,
        ownerPhone: _ownerPhoneController.text,
        inspectionDate: _inspectionDate,
        insuranceDate: _insuranceDate,
      );
      await _api.update(widget.vehicleId, vehicle);
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
        appBar: AppBar(title: const Text('编辑车辆')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑车辆'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('车牌号 *', _plateController, required: true),
            _field('车架号/VIN', _vinController),
            _field('品牌', _brandController),
            _field('型号', _modelController),
            _field('年份', _yearController, keyboardType: TextInputType.number),
            _field('颜色', _colorController),
            _field('车主姓名', _ownerNameController),
            _field(
              '车主电话',
              _ownerPhoneController,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '必填' : null
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _plateController.dispose();
    _vinController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }
}
