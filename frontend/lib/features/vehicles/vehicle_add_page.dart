import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/api/ocr_api.dart';
import '../../core/api/vehicle_api.dart';
import '../../models/vehicle.dart';

class VehicleAddPage extends StatefulWidget {
  final String? initialPlate;
  final String? initialVin;
  const VehicleAddPage({super.key, this.initialPlate, this.initialVin});

  @override
  State<VehicleAddPage> createState() => _VehicleAddPageState();
}

class _VehicleAddPageState extends State<VehicleAddPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _vinController;
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  String? _inspectionDate;
  String? _insuranceDate;
  bool _saving = false;

  final _ocrApi = OcrApi();
  final _vehicleApi = VehicleApi();

  String? _photoUrl; // store uploaded photo URL

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController(text: widget.initialPlate);
    _vinController = TextEditingController(text: widget.initialVin);
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
    );
    if (file != null) {
      try {
        final url = await _vehicleApi.uploadPhoto(file);
        setState(() => _photoUrl = url);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('照片上传成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('上传失败：$e')));
        }
      }
    }
  }

  Future<void> _scanPlate() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
    );
    if (file != null) {
      try {
        final result = await _ocrApi.scanPlate(file);
        if (result.isNotEmpty) {
          _plateController.text = result;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('识别失败，请重试')));
        }
      }
    }
  }

  Future<void> _scanVin() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
    );
    if (file != null) {
      try {
        final result = await _ocrApi.scanVin(file);
        if (result.isNotEmpty) {
          _vinController.text = result;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('识别失败，请重试')));
        }
      }
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
        photoUrl: _photoUrl,
      );
      await _vehicleApi.create(vehicle);
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

  Future<void> _pickDate(bool isInspection) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date != null) {
      final str =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      setState(() {
        if (isInspection) {
          _inspectionDate = str;
        } else {
          _insuranceDate = str;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增车辆'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
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
            _buildPhotoSection(),
            const SizedBox(height: 16),
            _buildOcrSection(),
            const SizedBox(height: 16),
            _buildField(
              '车牌号 *',
              _plateController,
              required: true,
              hint: '粤B·12345',
            ),
            _buildField('车架号/VIN', _vinController, hint: '17位车架号'),
            _buildField('品牌', _brandController),
            _buildField('型号', _modelController),
            _buildField(
              '年份',
              _yearController,
              keyboardType: TextInputType.number,
            ),
            _buildField('颜色', _colorController),
            _buildField('车主姓名', _ownerNameController),
            _buildField(
              '车主电话',
              _ownerPhoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildDatePicker('年检到期日', _inspectionDate, () => _pickDate(true)),
            _buildDatePicker('保险到期日', _insuranceDate, () => _pickDate(false)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.bgLight,
        ),
        child: _photoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _photoUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    size: 40,
                    color: AppTheme.textHint,
                  ),
                ),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      size: 40,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '点击拍照',
                      style: TextStyle(color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOcrSection() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _scanPlate,
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('扫车牌'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _scanVin,
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('扫车架号'),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '必填' : null
            : null,
      ),
    );
  }

  Widget _buildDatePicker(String label, String? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
          ),
          child: Text(
            value ?? '点击选择日期',
            style: TextStyle(
              color: value != null ? AppTheme.textPrimary : AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
