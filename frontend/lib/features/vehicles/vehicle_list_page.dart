import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/vehicle_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/vehicle.dart';

class VehicleListPage extends StatefulWidget {
  const VehicleListPage({super.key});

  @override
  State<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  final _api = VehicleApi();
  final _searchController = TextEditingController();
  final _currencyPattern = RegExp(r'\B(?=(\d{3})+(?!\d))');
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _vehicles = await _api.getList(
        search: _search.isNotEmpty ? _search : null,
      );
    } catch (_) {
      _vehicles = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除车辆档案'),
        content: Text('确定从车辆档案删除 ${v.plateNumber}？历史工单和账目会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && v.id != null) {
      try {
        await _api.delete(v.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('车辆档案已删除')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('删除失败')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSpend = _vehicles.fold<double>(
      0,
      (sum, v) => sum + (v.totalCost ?? 0),
    );
    final activeCars = _vehicles.where((v) => (v.recordCount ?? 0) > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('客户与车辆档案')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                AppSurfaceCard(
                  radius: AppRadius.large,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SoftIcon(
                        icon: Icons.groups_rounded,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '客户资产',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_vehicles.length} 辆车 · $activeCars 个活跃客户',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '累计消费 ¥${_formatMoney(totalSpend)}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filled(
                        tooltip: '新增车辆',
                        onPressed: () async {
                          await context.push('/vehicles/add');
                          _loadData();
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索车牌号、车架号、车主姓名或电话',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            tooltip: '清空',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                              _loadData();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        setState(() => _search = value);
                        _loadData();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _vehicles.isEmpty
                  ? EmptyState(
                      icon: Icons.directions_car_filled_rounded,
                      title: '暂无车辆档案',
                      subtitle: '录入客户车辆后可查看消费总额、历史工单和最近到店',
                      action: FilledButton.icon(
                        onPressed: () => context.push('/vehicles/add'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('添加车辆'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: _vehicles.length,
                      itemBuilder: (_, i) => _buildCard(_vehicles[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'vehicle_add',
        onPressed: () async {
          await context.push('/vehicles/add');
          _loadData();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildCard(Vehicle v) {
    final active = (v.recordCount ?? 0) > 0;
    final subtitle = [
      if ((v.brand ?? '').isNotEmpty) v.brand,
      if ((v.model ?? '').isNotEmpty) v.model,
      if (v.year != null) '${v.year}',
      if ((v.color ?? '').isNotEmpty) v.color,
    ].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        onTap: () async {
          await context.push('/vehicles/${v.id}');
          _loadData();
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SoftIcon(
                  icon: Icons.directions_car_rounded,
                  color: AppTheme.primary,
                  size: 48,
                  iconSize: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              v.plateNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: active ? '活跃客户' : '新客户',
                            color: active ? AppTheme.success : AppTheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle.isEmpty ? '未录入车型信息' : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '删除档案',
                  onPressed: () => _deleteVehicle(v),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoMetric(
                    label: '车主',
                    value: (v.ownerName ?? '').isEmpty ? '-' : v.ownerName!,
                  ),
                ),
                Expanded(
                  child: _InfoMetric(
                    label: '历史工单',
                    value: '${v.recordCount ?? 0} 单',
                  ),
                ),
                Expanded(
                  child: _InfoMetric(
                    label: '消费总额',
                    value: '¥${_formatMoney(v.totalCost ?? 0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.textHint,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '最近到店：${v.lastRecordDate ?? "暂无记录"}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textHint,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(double value) {
    final fixed = value.toStringAsFixed(0);
    return fixed.replaceAllMapped(_currencyPattern, (match) => ',');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class _InfoMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InfoMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
