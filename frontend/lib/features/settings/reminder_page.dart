import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api/api_client.dart';
import '../../models/dashboard_stats.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  DashboardStats? _stats;
  List<Map<String, dynamic>> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await apiClientProvider.get('/dashboard');
      _stats = DashboardStats.fromJson(res.data);
      _reminders = _stats?.reminders ?? [];
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('提醒管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _reminders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: AppTheme.textHint,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '暂无提醒',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _reminders.length,
                      itemBuilder: (_, i) => _buildItem(_reminders[i]),
                    ),
            ),
    );
  }

  Widget _buildItem(Map<String, dynamic> r) {
    final plate = r['plate_number']?.toString() ?? '';
    final date = r['reminder_date']?.toString() ?? '';
    final mileage = r['reminder_mileage'];
    final daysLeft = (r['days_left'] as num?)?.toInt() ?? 0;
    final isOverdue = daysLeft < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: isOverdue ? AppTheme.danger : AppTheme.warning,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '提醒日期：$date',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (mileage != null)
                    Text(
                      '提醒里程：$mileage km',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOverdue
                    ? AppTheme.danger.withValues(alpha: 0.1)
                    : AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isOverdue ? '超期${-daysLeft}天' : '$daysLeft天',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOverdue ? AppTheme.danger : AppTheme.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
