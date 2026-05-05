import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/vehicle.dart';
import '../../models/record.dart';
import '../../core/theme.dart';
import '../../core/api/vehicle_api.dart';
import '../../core/api/record_api.dart';

class VehicleDetailPage extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailPage({super.key, required this.vehicleId});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  final _vehicleApi = VehicleApi();
  final _recordApi = RecordApi();
  Vehicle? _vehicle;
  List<Record> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _vehicle = await _vehicleApi.getById(widget.vehicleId);
      _records = await _recordApi.getList(vehicleId: widget.vehicleId);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('车辆详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final v = _vehicle;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('车辆详情')),
        body: const Center(child: Text('未找到车辆')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('车辆详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              await context.push('/vehicles/${widget.vehicleId}/edit');
              _loadData();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(v),
          const SizedBox(height: 16),
          _buildInfoCard(v),
          const SizedBox(height: 16),
          _buildStats(),
          const SizedBox(height: 20),
          _buildSectionTitle('维修历史'),
          ..._records.map((r) => _buildRecordItem(r)),
          if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '暂无维修记录',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textHint),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await context.push('/records/add?vehicleId=${widget.vehicleId}');
              _loadData();
            },
            icon: const Icon(Icons.add),
            label: const Text('新增维修'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(Vehicle v) => Container(
    height: 160,
    decoration: BoxDecoration(
      color: AppTheme.primaryLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_rounded,
            size: 48,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            v.plateNumber,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          Text(
            '${v.brand ?? ""} ${v.model ?? ""} · ${v.year ?? ""} · ${v.color ?? ""}',
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _buildInfoCard(Vehicle v) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoRow('车主', v.ownerName ?? '-'),
          const Divider(),
          _infoRow('电话', v.ownerPhone ?? '-'),
          const Divider(),
          _infoRow('车架号', v.vin ?? '-'),
          const Divider(),
          _infoRow('年检到期', v.inspectionDate ?? '-'),
          const Divider(),
          _infoRow('保险到期', v.insuranceDate ?? '-'),
        ],
      ),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _buildStats() {
    final totalCost = _records.fold(0.0, (sum, r) => sum + (r.cost ?? 0));
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    '${_records.length}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Text(
                    '维修次数',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    '¥${totalCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.income,
                    ),
                  ),
                  const Text(
                    '总费用',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );

  Widget _buildRecordItem(Record r) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/records/${r.id}'),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.build_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          r.categoryName ?? r.items ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          '${r.recordDate} · ${r.mileage ?? ""}km',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Text(
          '¥${r.cost?.toStringAsFixed(0) ?? "-"}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.income,
          ),
        ),
      ),
    ),
  );
}
