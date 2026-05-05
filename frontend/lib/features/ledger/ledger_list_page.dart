import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/ledger_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/ledger.dart';

class LedgerListPage extends StatefulWidget {
  const LedgerListPage({super.key});

  @override
  State<LedgerListPage> createState() => _LedgerListPageState();
}

class _LedgerListPageState extends State<LedgerListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ledgerApi = LedgerApi();
  List<Ledger> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
      _loadData();
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _items = await _ledgerApi.getList(
        type: _tabController.index == 0 ? 'income' : 'expense',
      );
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Ledger> get _filtered => _items;
  double get _total => _filtered.fold(0, (sum, l) => sum + l.amount);
  bool get _isIncome => _tabController.index == 0;

  @override
  Widget build(BuildContext context) {
    final color = _isIncome ? AppTheme.success : AppTheme.expense;
    return Scaffold(
      appBar: AppBar(title: const Text('收银结算')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                children: [
                  _buildCashierCard(color),
                  const SizedBox(height: 16),
                  _buildTabs(),
                  const SizedBox(height: 16),
                  _buildPaymentMethods(),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: _isIncome ? '收款流水' : '支出流水',
                    subtitle: '按时间倒序查看门店资金记录',
                    actionText: '记一笔',
                    onAction: () async {
                      await context.push('/ledger/add');
                      _loadData();
                    },
                  ),
                  if (_filtered.isEmpty)
                    const AppSurfaceCard(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: '暂无流水记录',
                        subtitle: '完成收款或记账后会显示在这里',
                      ),
                    )
                  else
                    ..._filtered.map(_buildCard),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ledger_add',
        onPressed: () async {
          await context.push('/ledger/add');
          _loadData();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_isIncome ? '新增收款' : '新增支出'),
      ),
    );
  }

  Widget _buildCashierCard(Color color) {
    return AppSurfaceCard(
      radius: AppRadius.large,
      padding: const EdgeInsets.all(20),
      shadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      gradient: LinearGradient(
        colors: _isIncome
            ? const [AppTheme.primary, Color(0xFF12BFA5)]
            : const [Color(0xFFEF4444), Color(0xFFF59E0B)],
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
                child: Icon(
                  _isIncome
                      ? Icons.point_of_sale_rounded
                      : Icons.outbox_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isIncome ? '今日收银台' : '门店支出台',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '已核对',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _isIncome ? '收款合计' : '支出合计',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '¥${_total.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.push('/ledger/add');
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: color,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: Icon(
                    _isIncome
                        ? Icons.check_circle_rounded
                        : Icons.add_card_rounded,
                    size: 18,
                  ),
                  label: Text(_isIncome ? '确认收款' : '记录支出'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/records'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.assignment_rounded, size: 18),
                  label: const Text('关联工单'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(5),
      shadow: AppShadows.soft,
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _isIncome ? AppTheme.primary : AppTheme.expense,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '收入'),
          Tab(text: '支出'),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      (Icons.qr_code_rounded, '微信/支付宝', AppTheme.primary),
      (Icons.credit_card_rounded, '银行卡', AppTheme.secondary),
      (Icons.payments_rounded, '现金', AppTheme.warning),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '支付方式', subtitle: '门店快速收款核对'),
        Row(
          children: [
            for (final method in methods) ...[
              Expanded(
                child: AppSurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  shadow: [
                    BoxShadow(
                      color: method.$3.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  child: Column(
                    children: [
                      SoftIcon(
                        icon: method.$1,
                        color: method.$3,
                        size: 38,
                        iconSize: 19,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        method.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (method != methods.last) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCard(Ledger l) {
    final income = l.type == 'income';
    final color = income ? AppTheme.success : AppTheme.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        onTap: () => context.push('/ledger/${l.id}'),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            SoftIcon(
              icon: income
                  ? Icons.add_circle_rounded
                  : Icons.remove_circle_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.categoryName?.isNotEmpty == true
                        ? l.categoryName!
                        : income
                        ? '维修收款'
                        : '门店支出',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      l.recordDate,
                      if ((l.description ?? '').isNotEmpty) l.description!,
                    ].join(' · '),
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
            const SizedBox(width: 10),
            Text(
              '${income ? "+" : "-"}¥${l.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
