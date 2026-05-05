import 'package:flutter/material.dart';

import '../../core/api/stats_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/business_stats.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _api = StatsApi();
  BusinessStats? _stats;
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _stats = await _api.getOverview(days: _days);
    } catch (_) {
      _stats = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('数据统计')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _buildPeriodSwitch(),
                  const SizedBox(height: 14),
                  _buildHero(stats),
                  const SizedBox(height: 16),
                  _buildMetricGrid(stats),
                  const SizedBox(height: 22),
                  const SectionHeader(title: '营业趋势', subtitle: '收入与支出走势'),
                  AppSurfaceCard(
                    padding: const EdgeInsets.all(16),
                    child: _TrendChart(data: stats?.trend ?? []),
                  ),
                  const SizedBox(height: 22),
                  const SectionHeader(title: '维修分类排行', subtitle: '按收入贡献排序'),
                  _buildRanking(stats?.categories ?? []),
                  const SizedBox(height: 22),
                  const SectionHeader(title: '热销项目', subtitle: '按工单次数排序'),
                  _buildRanking(stats?.hotItems ?? [], countKey: 'count'),
                ],
              ),
      ),
    );
  }

  Widget _buildPeriodSwitch() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final option in const [(7, '7天'), (30, '30天'), (90, '90天')])
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _days = option.$1);
                  _loadData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _days == option.$1
                        ? AppTheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      color: _days == option.$1
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(BusinessStats? stats) {
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '经营数据看板',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            '营业额',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '¥${(stats?.income ?? 0).toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(BusinessStats? stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.18,
      children: [
        MetricCard(
          title: '工单数',
          value: '${stats?.recordCount ?? 0} 单',
          icon: Icons.assignment_rounded,
          color: AppTheme.primary,
        ),
        MetricCard(
          title: '客单价',
          value: '¥${(stats?.avgOrderAmount ?? 0).toStringAsFixed(0)}',
          icon: Icons.sell_rounded,
          color: AppTheme.secondary,
        ),
        MetricCard(
          title: '支出',
          value: '¥${(stats?.expense ?? 0).toStringAsFixed(0)}',
          icon: Icons.trending_down_rounded,
          color: AppTheme.danger,
        ),
        MetricCard(
          title: '利润',
          value: '¥${(stats?.profit ?? 0).toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_rounded,
          color: AppTheme.success,
        ),
      ],
    );
  }

  Widget _buildRanking(
    List<Map<String, dynamic>> rows, {
    String countKey = 'record_count',
  }) {
    if (rows.isEmpty) {
      return const AppSurfaceCard(
        child: EmptyState(
          icon: Icons.bar_chart_rounded,
          title: '暂无统计数据',
          subtitle: '产生工单和收银流水后会生成排行',
        ),
      );
    }
    final max = rows
        .map((e) => (e['income'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: rows.take(6).map((row) {
        final income = (row['income'] as num?)?.toDouble() ?? 0;
        final ratio = max == 0 ? 0.0 : income / max;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['name']?.toString() ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '${row[countKey] ?? 0} 单 · ¥${income.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: AppTheme.bgLight,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _TrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 180,
        child: EmptyState(icon: Icons.show_chart_rounded, title: '暂无趋势数据'),
      );
    }
    final max = data
        .map(
          (e) =>
              ((e['income'] as num?)?.toDouble() ?? 0) +
              ((e['expense'] as num?)?.toDouble() ?? 0),
        )
        .fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.take(14).map((row) {
          final income = (row['income'] as num?)?.toDouble() ?? 0;
          final expense = (row['expense'] as num?)?.toDouble() ?? 0;
          final incomeHeight = max == 0 ? 0.0 : income / max;
          final expenseHeight = max == 0 ? 0.0 : expense / max;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: FractionallySizedBox(
                              heightFactor: incomeHeight.clamp(0.05, 1),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: FractionallySizedBox(
                              heightFactor: expenseHeight.clamp(0.05, 1),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.warning,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    row['date']?.toString().substring(5) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
