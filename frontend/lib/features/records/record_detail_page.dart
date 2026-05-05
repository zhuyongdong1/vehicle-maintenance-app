import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/record_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/record.dart';

class RecordDetailPage extends StatefulWidget {
  final int recordId;
  const RecordDetailPage({super.key, required this.recordId});

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  final _api = RecordApi();
  Record? _record;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _record = await _api.getById(widget.recordId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('工单详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final r = _record;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('工单详情')),
        body: const Center(child: Text('未找到记录')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('工单详情'),
        actions: [
          IconButton(
            tooltip: '编辑',
            onPressed: () async {
              await context.push('/records/${widget.recordId}/edit');
              _loadData();
            },
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _buildHeader(r),
          const SizedBox(height: 22),
          const SectionHeader(title: '状态流转', subtitle: '从接车到结算的工单进度'),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: _buildTimeline(r),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '客户与车辆', subtitle: '当前工单关联档案'),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LabeledValue(label: '车牌号', value: r.plateNumber ?? '-'),
                const Divider(height: 1),
                LabeledValue(label: '车辆信息', value: r.vehicleInfo ?? '-'),
                if (r.mileage != null) ...[
                  const Divider(height: 1),
                  LabeledValue(label: '进店里程', value: '${r.mileage} km'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '维修明细', subtitle: '项目、配件和维修说明'),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LabeledValue(label: '维修分类', value: r.categoryName ?? '-'),
                const Divider(height: 1),
                LabeledValue(label: '维修项目', value: r.items ?? '-'),
                const Divider(height: 1),
                LabeledValue(label: '维修日期', value: r.recordDate),
                if ((r.workshop ?? '').isNotEmpty) ...[
                  const Divider(height: 1),
                  LabeledValue(label: '维修厂', value: r.workshop!),
                ],
                if ((r.parts ?? '').isNotEmpty) ...[
                  const Divider(height: 1),
                  LabeledValue(label: '配件明细', value: r.parts!),
                ],
                if ((r.notes ?? '').isNotEmpty) ...[
                  const Divider(height: 1),
                  LabeledValue(label: '备注', value: r.notes!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '金额信息', subtitle: '进价、售价和毛利核对'),
          AppSurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                if (r.feeItems.isNotEmpty) ...[
                  const _FeeTableHeader(),
                  const SizedBox(height: 8),
                  for (final item in r.feeItems) _FeeRow(item: item),
                  const Divider(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _AmountTile(
                        label: '进价合计',
                        value: r.purchaseCost ?? 0,
                        color: AppTheme.expense,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AmountTile(
                        label: '售价合计',
                        value: r.cost ?? 0,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AmountTile(
                        label: '毛利',
                        value: (r.cost ?? 0) - (r.purchaseCost ?? 0),
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '维修照片', subtitle: '用于交车验收的图片记录'),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 116,
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
                      icon: Icons.photo_library_outlined,
                      color: AppTheme.textHint,
                      size: 46,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '当前工单暂无照片',
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
          if ((r.reminderDate != null && r.reminderDate!.isNotEmpty) ||
              r.reminderMileage != null) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: '保养提醒', subtitle: '交车后回访依据'),
            AppSurfaceCard(
              padding: const EdgeInsets.all(16),
              color: AppTheme.warning.withValues(alpha: 0.08),
              shadow: [
                BoxShadow(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
              child: Row(
                children: [
                  const SoftIcon(
                    icon: Icons.notifications_active_rounded,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (r.reminderDate != null)
                          Text(
                            '提醒日期：${r.reminderDate}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        if (r.reminderMileage != null)
                          Text(
                            '提醒里程：${r.reminderMileage} km',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const StatusPill(label: '待跟进', color: AppTheme.warning),
                ],
              ),
            ),
          ],
        ],
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _notConnected,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('开始维修'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _notConnected,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('完工'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/ledger/add'),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('结算'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Record r) {
    final hasAmount = r.cost != null && r.cost! > 0;
    return AppSurfaceCard(
      radius: AppRadius.large,
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        colors: [AppTheme.primary, Color(0xFF46A6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.car_repair_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.plateNumber ?? '未录车牌',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      r.categoryName ?? r.items ?? '维修工单',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: hasAmount ? '待结算' : '待报价', color: Colors.white),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeaderInfo(label: '开单日期', value: r.recordDate),
              _HeaderInfo(
                label: '里程',
                value: r.mileage == null ? '-' : '${r.mileage} km',
              ),
              _HeaderInfo(
                label: '金额',
                value: '¥${r.cost?.toStringAsFixed(0) ?? "-"}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Record r) {
    final steps = [
      ('接车开单', true, AppTheme.primary),
      ('维修施工', true, AppTheme.secondary),
      ('完工质检', (r.notes ?? '').isNotEmpty, AppTheme.warning),
      ('收银结算', r.cost != null && r.cost! > 0, AppTheme.success),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: steps[i].$2 ? steps[i].$3 : AppTheme.divider,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      steps[i].$2 ? Icons.check_rounded : Icons.circle,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (i != steps.length - 1)
                    Container(width: 2, height: 34, color: AppTheme.divider),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$2 ? '已完成' : '待处理',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _notConnected() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前版本未接入工单状态流转接口')));
  }
}

class _FeeTableHeader extends StatelessWidget {
  const _FeeTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );
    return const Row(
      children: [
        Expanded(flex: 5, child: Text('项目', style: style)),
        Expanded(flex: 3, child: Text('进价', style: style)),
        Expanded(flex: 3, child: Text('售价', style: style)),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  final RecordFeeItem item;

  const _FeeRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              item.item.isEmpty ? '-' : item.item,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text('¥${(item.purchasePrice ?? 0).toStringAsFixed(2)}'),
          ),
          Expanded(
            flex: 3,
            child: Text('¥${(item.salePrice ?? 0).toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AmountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥${value.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
