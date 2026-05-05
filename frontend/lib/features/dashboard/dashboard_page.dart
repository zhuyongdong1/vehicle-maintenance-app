import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/api/dashboard_api.dart';
import '../../core/api/ocr_api.dart';
import '../../core/api/vehicle_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/dashboard_stats.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _api = DashboardApi();
  final _ocrApi = OcrApi();
  final _vehicleApi = VehicleApi();
  DashboardStats? _stats;
  bool _loading = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _stats = await _api.getStats();
    } catch (e) {
      _stats = DashboardStats(
        monthIncome: 0,
        monthExpense: 0,
        monthProfit: 0,
        monthRecordCount: 0,
        reminders: [],
        recentRecords: [],
        recentLedger: [],
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('门店工作台'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          children: [
            if (_loading)
              ..._buildSkeletons()
            else ...[
              _buildHero(s),
              const SizedBox(height: 18),
              _buildMetrics(s),
              const SizedBox(height: 22),
              _buildShortcuts(),
              const SizedBox(height: 22),
              _buildBayStatus(),
              const SizedBox(height: 22),
              if (s != null && s.reminders.isNotEmpty) ...[
                _buildReminders(s.reminders),
                const SizedBox(height: 22),
              ],
              if (s != null) _buildTodayOrders(s),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_record_add',
        onPressed: () => context.push('/records/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('接车开单'),
      ),
    );
  }

  Widget _buildHero(DashboardStats? s) {
    final currencyFmt = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '¥',
      decimalDigits: 0,
    );
    return AppSurfaceCard(
      radius: AppRadius.large,
      padding: const EdgeInsets.all(20),
      shadow: [
        BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.2),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      gradient: const LinearGradient(
        colors: [AppTheme.primary, Color(0xFF46A6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今天 ${DateFormat('M月d日').format(DateTime.now())}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '汽修门店经营概览',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: '营业中', color: Colors.white),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月营业额',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyFmt.format(s?.monthIncome ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _HeroMiniStat(
                label: '净利润',
                value: currencyFmt.format(s?.monthProfit ?? 0),
              ),
              const SizedBox(width: 10),
              _HeroMiniStat(label: '工单', value: '${s?.monthRecordCount ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(DashboardStats? s) {
    final currencyFmt = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: '¥',
      decimalDigits: 0,
    );
    final todayIncome = _todayIncome(s);
    final todayCount = _todayRecordCount(s);
    final reminderCount = s?.reminders.length ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: [
        MetricCard(
          title: '今日营业额',
          value: currencyFmt.format(todayIncome),
          subtitle: '来自最近工单',
          icon: Icons.payments_rounded,
          color: AppTheme.primary,
        ),
        MetricCard(
          title: '今日进店车辆',
          value: '$todayCount 台',
          subtitle: '待确认交车',
          icon: Icons.directions_car_rounded,
          color: AppTheme.secondary,
        ),
        MetricCard(
          title: '待处理提醒',
          value: '$reminderCount 项',
          subtitle: reminderCount > 0 ? '需跟进回访' : '暂无逾期',
          icon: Icons.notifications_active_rounded,
          color: AppTheme.warning,
        ),
        const MetricCard(
          title: '库存预警',
          value: '待接入',
          subtitle: '配件库存模块',
          icon: Icons.inventory_2_rounded,
          color: AppTheme.danger,
        ),
      ],
    );
  }

  Widget _buildShortcuts() {
    final shortcuts = [
      (
        label: '接车开单',
        icon: Icons.assignment_add,
        color: AppTheme.primary,
        onTap: () => context.push('/records/add'),
      ),
      (
        label: '扫车牌',
        icon: Icons.document_scanner_rounded,
        color: AppTheme.secondary,
        onTap: _scanning ? () {} : () => _handleScan(isPlate: true),
      ),
      (
        label: '车辆档案',
        icon: Icons.manage_search_rounded,
        color: AppTheme.warning,
        onTap: () => context.push('/vehicles'),
      ),
      (
        label: '收银记账',
        icon: Icons.point_of_sale_rounded,
        color: AppTheme.success,
        onTap: () => context.push('/ledger/add'),
      ),
      (
        label: '库存管理',
        icon: Icons.inventory_2_rounded,
        color: AppTheme.danger,
        onTap: () => context.push('/inventory'),
      ),
      (
        label: '数据统计',
        icon: Icons.analytics_rounded,
        color: AppTheme.primaryDark,
        onTap: () => context.push('/stats'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '快捷操作', subtitle: '高频业务一键进入'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.92,
          children: shortcuts
              .map(
                (item) => ActionShortcut(
                  label: item.label,
                  icon: item.icon,
                  color: item.color,
                  onTap: item.onTap,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBayStatus() {
    const bays = [
      ('1号工位', '施工中', AppTheme.primary, 72),
      ('2号工位', '待质检', AppTheme.warning, 46),
      ('3号工位', '空闲', AppTheme.success, 12),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '工位状态', subtitle: '用于门店现场排班查看'),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final bay in bays) ...[
                _BayRow(
                  name: bay.$1,
                  status: bay.$2,
                  color: bay.$3,
                  progress: bay.$4 / 100,
                ),
                if (bay != bays.last) const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReminders(List<Map<String, dynamic>> reminders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '待办提醒',
          subtitle: '保养、年检、保险到期跟进',
          actionText: '查看全部',
          onAction: () => context.push('/reminders'),
        ),
        ...reminders.take(3).map((r) {
          final daysLeft = (r['days_left'] as num?)?.toInt() ?? 0;
          final isOverdue = daysLeft < 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SoftIcon(
                    icon: Icons.notifications_active_rounded,
                    color: isOverdue ? AppTheme.danger : AppTheme.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['plate_number']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOverdue ? '已超期 ${-daysLeft} 天' : '$daysLeft 天后到期',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: isOverdue ? '逾期' : '待跟进',
                    color: isOverdue ? AppTheme.danger : AppTheme.warning,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTodayOrders(DashboardStats s) {
    final records = s.recentRecords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '今日工单',
          subtitle: '最近开单和维修动态',
          actionText: '全部工单',
          onAction: () => context.push('/records'),
        ),
        if (records.isEmpty)
          const AppSurfaceCard(
            child: EmptyState(
              icon: Icons.assignment_outlined,
              title: '暂无工单动态',
              subtitle: '接车开单后会出现在这里',
            ),
          )
        else
          ...records
              .take(5)
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppSurfaceCard(
                    onTap: () {
                      final id = r['id'];
                      if (id != null) context.push('/records/$id');
                    },
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const SoftIcon(
                          icon: Icons.build_circle_rounded,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['plate_number'] ?? "未录车牌"} · ${r['category_name'] ?? "维修工单"}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                r['record_date']?.toString() ?? '今日',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '¥${(r['cost'] as num?)?.toStringAsFixed(0) ?? "-"}',
                          style: const TextStyle(
                            color: AppTheme.income,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
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

  Future<void> _handleScan({required bool isPlate}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
    );
    if (file == null) return;

    setState(() => _scanning = true);

    try {
      final result = isPlate
          ? await _ocrApi.scanPlate(file)
          : await _ocrApi.scanVin(file);

      if (result.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未能识别出信息，请重新扫描')));
        }
        if (mounted) setState(() => _scanning = false);
        return;
      }

      final vehicles = await _vehicleApi.getList(search: result);

      if (!mounted) return;
      setState(() => _scanning = false);

      if (vehicles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已找到车辆：$result'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.push('/vehicles/${vehicles.first.id}');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('未找到车辆，请录入信息\n识别结果：$result')));
        final queryParams = isPlate ? '?plate=$result' : '?vin=$result';
        context.push('/vehicles/add$queryParams');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('扫描处理失败：$e')));
      }
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<Widget> _buildSkeletons() => List.generate(
    5,
    (_) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.white,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
  );

  double _todayIncome(DashboardStats? s) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return s?.recentRecords.fold<double>(0, (sum, r) {
          if (r['record_date']?.toString() != today) return sum;
          return sum + ((r['cost'] as num?)?.toDouble() ?? 0);
        }) ??
        0;
  }

  int _todayRecordCount(DashboardStats? s) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return s?.recentRecords
            .where((r) => r['record_date']?.toString() == today)
            .length ??
        0;
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
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
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BayRow extends StatelessWidget {
  final String name;
  final String status;
  final Color color;
  final double progress;

  const _BayRow({
    required this.name,
    required this.status,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SoftIcon(icon: Icons.car_repair_rounded, color: color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: AppTheme.bgLight,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
