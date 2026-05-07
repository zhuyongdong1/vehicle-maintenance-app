import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/category_api.dart';
import '../../core/api/record_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/category.dart';
import '../../models/record.dart';

class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key});

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  final _recordApi = RecordApi();
  final _categoryApi = CategoryApi();
  final _searchController = TextEditingController();
  List<Record> _records = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _loading = true;
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await _categoryApi.getList('maintenance_type');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _records = await _recordApi.getList(
        categoryId: _selectedCategoryId,
        search: _search,
      );
    } catch (_) {
      _records = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _records.fold<double>(
      0,
      (sum, r) => sum + (r.cost ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('工单管理'),
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  radius: AppRadius.large,
                  child: Row(
                    children: [
                      const SoftIcon(
                        icon: Icons.assignment_rounded,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '当前工单',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_records.length} 单 · ¥${totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await context.push('/records/add');
                          _loadData();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('开单'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(92, 44),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索车牌、项目、维修厂',
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
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final isAll = i == 0;
                      final selected = isAll
                          ? _selectedCategoryId == null
                          : _selectedCategoryId == _categories[i - 1].id;
                      return FilterChip(
                        label: Text(isAll ? '全部工单' : _categories[i - 1].name),
                        selected: selected,
                        onSelected: (_) {
                          setState(
                            () => _selectedCategoryId = isAll
                                ? null
                                : _categories[i - 1].id,
                          );
                          _loadData();
                        },
                        selectedColor: AppTheme.primaryLight,
                        checkmarkColor: AppTheme.primary,
                        side: BorderSide(
                          color: selected ? AppTheme.primary : AppTheme.divider,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                  ? EmptyState(
                      icon: Icons.assignment_outlined,
                      title: '暂无工单',
                      subtitle: '接车开单后可在这里跟踪维修、结算和回访',
                      action: FilledButton.icon(
                        onPressed: () async {
                          await context.push('/records/add');
                          _loadData();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('新建工单'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: _records.length,
                      itemBuilder: (_, i) => _buildCard(_records[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'record_add',
        onPressed: () async {
          await context.push('/records/add');
          _loadData();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildCard(Record r) {
    final statusMeta = _statusMeta(r);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('record_${r.id}_${r.updatedAt ?? r.recordDate}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await context.push('/records/${r.id}/edit');
            _loadData();
          } else {
            await context.push('/ledger/add');
          }
          return false;
        },
        background: _slideAction(
          alignment: Alignment.centerLeft,
          icon: Icons.edit_rounded,
          label: '编辑',
          color: AppTheme.primary,
        ),
        secondaryBackground: _slideAction(
          alignment: Alignment.centerRight,
          icon: Icons.payments_rounded,
          label: '结算',
          color: AppTheme.success,
        ),
        child: AppSurfaceCard(
          onTap: () => context.push('/records/${r.id}'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SoftIcon(
                    icon: Icons.car_repair_rounded,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.plateNumber?.isNotEmpty == true
                              ? r.plateNumber!
                              : '未录车牌',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.vehicleInfo?.isNotEmpty == true
                              ? r.vehicleInfo!
                              : r.recordDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(label: statusMeta.$1, color: statusMeta.$2),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                r.categoryName ?? r.items ?? '维修工单',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 16, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text(
                    r.recordDate,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (r.mileage != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: AppTheme.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${r.mileage} km',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '¥${r.cost?.toStringAsFixed(0) ?? "-"}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.income,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _CardAction(
                    icon: Icons.edit_rounded,
                    label: '编辑',
                    onTap: () async {
                      await context.push('/records/${r.id}/edit');
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 8),
                  _CardAction(
                    icon: Icons.payments_rounded,
                    label: '结算',
                    onTap: () => context.push('/ledger/add'),
                  ),
                  const SizedBox(width: 8),
                  _CardAction(
                    icon: Icons.check_circle_rounded,
                    label: '完工',
                    onTap: () => _updateStatus(r, 'completed'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _statusMeta(Record record) {
    return switch (record.status) {
      'repairing' => ('维修中', AppTheme.secondary),
      'completed' => ('待收款', AppTheme.success),
      'settled' => ('已结算', AppTheme.primary),
      _ => (
        record.cost != null && record.cost! > 0 ? '待收款' : '待报价',
        AppTheme.warning,
      ),
    };
  }

  Future<void> _updateStatus(Record record, String status) async {
    final id = record.id;
    if (id == null) return;
    try {
      await _recordApi.updateStatus(id, status);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('工单状态已更新')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('工单状态更新失败')));
    }
  }

  Widget _slideAction({
    required Alignment alignment,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: color),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}
