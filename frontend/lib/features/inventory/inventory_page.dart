import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/inventory_api.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';
import '../../models/inventory.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _api = InventoryApi();
  final _searchController = TextEditingController();
  List<InventoryItem> _items = [];
  InventoryStats? _stats;
  bool _loading = true;
  bool _lowStockOnly = false;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getItems(search: _search, lowStock: _lowStockOnly),
        _api.getStats(),
      ]);
      _items = results[0] as List<InventoryItem>;
      _stats = results[1] as InventoryStats;
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存管理'),
        actions: [
          IconButton(
            tooltip: '新增配件',
            onPressed: () => _showItemDialog(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            _buildSummary(stats),
            const SizedBox(height: 16),
            _buildSearch(),
            const SizedBox(height: 18),
            SectionHeader(
              title: '配件库存',
              subtitle: '快速查询库存数量、预警和库位',
              actionText: _lowStockOnly ? '全部' : '只看预警',
              onAction: () {
                setState(() => _lowStockOnly = !_lowStockOnly);
                _loadData();
              },
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              AppSurfaceCard(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: '暂无库存配件',
                  subtitle: '添加配件后可进行入库、出库和库存预警管理',
                  action: FilledButton.icon(
                    onPressed: () => _showItemDialog(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加配件'),
                  ),
                ),
              )
            else
              ..._items.map(_buildItemCard),
            if (stats != null && stats.recentTransactions.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionHeader(title: '最近出入库', subtitle: '库存变化记录'),
              ...stats.recentTransactions.take(5).map(_buildTransactionCard),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增配件'),
      ),
    );
  }

  Widget _buildSummary(InventoryStats? stats) {
    return AppSurfaceCard(
      radius: AppRadius.large,
      padding: const EdgeInsets.all(18),
      gradient: const LinearGradient(
        colors: [AppTheme.primary, AppTheme.secondary],
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
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '轻量库存工作台',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(
                label: '${stats?.warningCount ?? 0} 项预警',
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryMetric(label: '配件种类', value: '${stats?.itemCount ?? 0}'),
              _SummaryMetric(label: '库存数量', value: '${stats?.stockCount ?? 0}'),
              _SummaryMetric(
                label: '库存成本',
                value: '¥${(stats?.stockValue ?? 0).toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '搜索配件名称、编码、供应商',
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
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          setState(() => _search = value);
          _loadData();
        });
      },
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final color = item.isLowStock ? AppTheme.warning : AppTheme.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIcon(icon: Icons.handyman_rounded, color: color, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          item.category ?? '未分类',
                          if ((item.sku ?? '').isNotEmpty) item.sku!,
                          if ((item.location ?? '').isNotEmpty) item.location!,
                        ].join(' · '),
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
                StatusPill(
                  label: item.isLowStock ? '库存预警' : '库存正常',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoMetric(
                    label: '当前库存',
                    value: '${item.stockQuantity} ${item.unit}',
                  ),
                ),
                Expanded(
                  child: _InfoMetric(
                    label: '预警值',
                    value: '${item.warningQuantity} ${item.unit}',
                  ),
                ),
                Expanded(
                  child: _InfoMetric(
                    label: '销售价',
                    value: '¥${item.salePrice.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStockDialog(item, 'in'),
                    icon: const Icon(Icons.call_received_rounded, size: 16),
                    label: const Text('入库'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showStockDialog(item, 'out'),
                    icon: const Icon(Icons.call_made_rounded, size: 16),
                    label: const Text('出库'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showItemDialog(item: item),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('编辑'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(InventoryTransaction tx) {
    final isIn = tx.type == 'in';
    final color = isIn ? AppTheme.success : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIcon(
              icon: isIn
                  ? Icons.add_circle_rounded
                  : Icons.remove_circle_rounded,
              color: color,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.itemName ?? '库存配件',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tx.createdAt ?? '',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIn ? "+" : "-"}${tx.quantity}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showItemDialog({InventoryItem? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final sku = TextEditingController(text: item?.sku ?? '');
    final unit = TextEditingController(text: item?.unit ?? '件');
    final stock = TextEditingController(text: '${item?.stockQuantity ?? 0}');
    final warning = TextEditingController(
      text: '${item?.warningQuantity ?? 5}',
    );
    final purchase = TextEditingController(text: '${item?.purchasePrice ?? 0}');
    final sale = TextEditingController(text: '${item?.salePrice ?? 0}');
    final supplier = TextEditingController(text: item?.supplier ?? '');
    final location = TextEditingController(text: item?.location ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item == null ? '新增配件' : '编辑配件',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '配件名称 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: '分类'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sku,
                decoration: const InputDecoration(labelText: '编码 SKU'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: '单位'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '库存'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: warning,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '预警值'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: sale,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '销售价'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purchase,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '进货价'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: supplier,
                decoration: const InputDecoration(labelText: '供应商'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: '库位'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  final payload = InventoryItem(
                    id: item?.id,
                    name: name.text.trim(),
                    category: category.text.trim(),
                    sku: sku.text.trim(),
                    unit: unit.text.trim().isEmpty ? '件' : unit.text.trim(),
                    stockQuantity: int.tryParse(stock.text) ?? 0,
                    warningQuantity: int.tryParse(warning.text) ?? 5,
                    purchasePrice: double.tryParse(purchase.text) ?? 0,
                    salePrice: double.tryParse(sale.text) ?? 0,
                    supplier: supplier.text.trim(),
                    location: location.text.trim(),
                  );
                  if (item == null) {
                    await _api.createItem(payload);
                  } else {
                    await _api.updateItem(item.id!, payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) _loadData();
  }

  Future<void> _showStockDialog(InventoryItem item, String type) async {
    final quantity = TextEditingController();
    final price = TextEditingController(
      text: type == 'in'
          ? item.purchasePrice.toString()
          : item.salePrice.toString(),
    );
    final notes = TextEditingController();
    final isIn = type == 'in';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isIn ? "入库" : "出库"} · ${item.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '数量 *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '单价'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final count = int.tryParse(quantity.text) ?? 0;
                if (count <= 0) return;
                await _api.createTransaction(
                  itemId: item.id!,
                  type: type,
                  quantity: count,
                  unitPrice: double.tryParse(price.text) ?? 0,
                  notes: notes.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(isIn ? '确认入库' : '确认出库'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

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
                  fontSize: 18,
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
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
