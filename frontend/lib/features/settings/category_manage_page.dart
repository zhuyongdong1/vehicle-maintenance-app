import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../core/theme.dart';
import '../../core/api/category_api.dart';

class CategoryManagePage extends StatefulWidget {
  final String
  categoryType; // 'maintenance_type', 'ledger_income', 'ledger_expense'
  const CategoryManagePage({super.key, required this.categoryType});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage> {
  List<Category> _categories = [];
  bool _loading = true;
  final _api = CategoryApi();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _title {
    switch (widget.categoryType) {
      case 'maintenance_type':
        return '维修类型';
      case 'ledger_income':
        return '收入分类';
      case 'ledger_expense':
        return '支出分类';
      default:
        return '分类管理';
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _categories = await _api.getList(widget.categoryType);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加新分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        await _api.create(Category(type: widget.categoryType, name: name));
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('添加失败：$e')));
        }
      }
    }
  }

  Future<void> _editCategory(Category cat) async {
    final controller = TextEditingController(text: cat.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分类名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && cat.id != null) {
      try {
        await _api.update(cat.id!, Category(type: cat.type, name: name));
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('修改失败：$e')));
        }
      }
    }
  }

  Future<void> _deleteCategory(Category cat) async {
    if (cat.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除"${cat.name}"？\n已有记录不受影响。'),
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
    if (confirm == true) {
      try {
        await _api.delete(cat.id!);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: _categories.length,
                itemBuilder: (_, i) => _buildItem(_categories[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cat_add',
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildItem(Category cat) {
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.drag_handle_rounded,
          color: AppTheme.textHint,
        ),
        title: Text(cat.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: () => _editCategory(cat),
            ),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppTheme.danger,
              ),
              onPressed: () => _deleteCategory(cat),
            ),
          ],
        ),
        onTap: () => _editCategory(cat),
      ),
    );
  }
}
