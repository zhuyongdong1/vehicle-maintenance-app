import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/app_update_api.dart';
import '../../core/api/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/ui/app_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _updateApi = AppUpdateApi();
  bool _checkingUpdate = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的 / 设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          AppSurfaceCard(
            radius: AppRadius.large,
            padding: const EdgeInsets.all(20),
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF5DB8FF)],
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
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '汽修门店管理',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '客户、工单、收银与提醒统一管理',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                    'v${AppConfig.appVersion}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '门店配置', subtitle: '维护分类、提醒和基础数据'),
          _buildGroup(
            children: [
              _buildTile(
                context: context,
                icon: Icons.build_rounded,
                color: AppTheme.primary,
                title: '维修类型',
                subtitle: '管理保养、维修、钣喷等工单分类',
                onTap: () =>
                    context.push('/settings/categories?type=maintenance_type'),
              ),
              _buildTile(
                context: context,
                icon: Icons.add_circle_outline_rounded,
                color: AppTheme.success,
                title: '收入分类',
                subtitle: '管理收款、维修收入等分类',
                onTap: () =>
                    context.push('/settings/categories?type=ledger_income'),
              ),
              _buildTile(
                context: context,
                icon: Icons.remove_circle_outline_rounded,
                color: AppTheme.danger,
                title: '支出分类',
                subtitle: '管理采购、房租、人工等支出分类',
                onTap: () =>
                    context.push('/settings/categories?type=ledger_expense'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '业务工具', subtitle: '交付前常用的数据与提醒能力'),
          _buildGroup(
            children: [
              _buildTile(
                context: context,
                icon: Icons.system_update_alt_rounded,
                color: AppTheme.primary,
                title: '检查更新',
                subtitle: _checkingUpdate
                    ? '正在检查新版本'
                    : '当前版本 v${AppConfig.appVersion}+${AppConfig.appBuildNumber}',
                onTap: _checkingUpdate ? () {} : () => _checkUpdate(context),
              ),
              _buildTile(
                context: context,
                icon: Icons.notifications_active_rounded,
                color: AppTheme.warning,
                title: '提醒管理',
                subtitle: '查看保养、年检、保险到期提醒',
                onTap: () => context.push('/reminders'),
              ),
              _buildTile(
                context: context,
                icon: Icons.inventory_2_rounded,
                color: AppTheme.primary,
                title: '库存管理',
                subtitle: '配件查询、库存预警、入库出库',
                onTap: () => context.push('/inventory'),
              ),
              _buildTile(
                context: context,
                icon: Icons.analytics_rounded,
                color: AppTheme.success,
                title: '数据统计',
                subtitle: '营业额、工单数、客单价和排行',
                onTap: () => context.push('/stats'),
              ),
              _buildTile(
                context: context,
                icon: Icons.file_download_rounded,
                color: AppTheme.secondary,
                title: '导出数据',
                subtitle: '导出 CSV，用于备份或财务核对',
                onTap: () => _exportData(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '系统状态', subtitle: '当前版本运行信息'),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: const [
                _StatusRow(label: '服务域名', value: 'ulbooks.cn'),
                Divider(height: 24),
                _StatusRow(label: '数据接口', value: '已启用鉴权'),
                Divider(height: 24),
                _StatusRow(label: 'OCR识别', value: '百度 OCR 已配置'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate(BuildContext context) async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await _updateApi.getLatest();
      if (!context.mounted) return;
      if (!info.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版 v${AppConfig.appVersion}')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v${info.versionName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.releaseNotes.isNotEmpty) Text(info.releaseNotes),
              if (info.publishedAt.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '发布时间：${info.publishedAt}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(info.required ? '稍后安装' : '稍后'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final url = Uri.parse(info.apkUrl);
                final launched = await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (!launched && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('无法打开更新下载地址')));
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('下载更新'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('检查更新失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final res = await apiClientProvider.get('/export');
      final csv = res.data.toString();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功，${csv.split('\n').length - 1} 条记录'),
            action: SnackBarAction(label: '确定', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  Widget _buildGroup({required List<Widget> children}) {
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 68, endIndent: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SoftIcon(icon: icon, color: color, size: 40, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
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
