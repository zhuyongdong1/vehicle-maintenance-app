import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/vehicles/vehicle_list_page.dart';
import '../features/vehicles/vehicle_add_page.dart';
import '../features/vehicles/vehicle_detail_page.dart';
import '../features/vehicles/vehicle_edit_page.dart';
import '../features/records/record_list_page.dart';
import '../features/records/record_add_page.dart';
import '../features/records/record_detail_page.dart';
import '../features/records/record_edit_page.dart';
import '../features/ledger/ledger_list_page.dart';
import '../features/ledger/ledger_add_page.dart';
import '../features/ledger/ledger_detail_page.dart';
import '../features/ledger/ledger_edit_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/stats/stats_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/category_manage_page.dart';
import '../features/settings/reminder_page.dart';

final router = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
        GoRoute(path: '/vehicles', builder: (_, __) => const VehicleListPage()),
        GoRoute(path: '/records', builder: (_, __) => const RecordListPage()),
        GoRoute(path: '/ledger', builder: (_, __) => const LedgerListPage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/inventory', builder: (_, __) => const InventoryPage()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
        GoRoute(
          path: '/settings/categories',
          builder: (_, state) => CategoryManagePage(
            categoryType:
                state.uri.queryParameters['type'] ?? 'maintenance_type',
          ),
        ),
        GoRoute(path: '/reminders', builder: (_, __) => const ReminderPage()),
      ],
    ),
    GoRoute(
      path: '/vehicles/add',
      builder: (_, state) => VehicleAddPage(
        initialPlate: state.uri.queryParameters['plate'],
        initialVin: state.uri.queryParameters['vin'],
      ),
    ),
    GoRoute(
      path: '/vehicles/:id',
      builder: (_, state) =>
          VehicleDetailPage(vehicleId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/vehicles/:id/edit',
      builder: (_, state) =>
          VehicleEditPage(vehicleId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/records/add',
      builder: (_, state) => RecordAddPage(
        vehicleId: state.uri.queryParameters['vehicleId'] != null
            ? int.parse(state.uri.queryParameters['vehicleId']!)
            : null,
      ),
    ),
    GoRoute(
      path: '/records/:id',
      builder: (_, state) =>
          RecordDetailPage(recordId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/records/:id/edit',
      builder: (_, state) =>
          RecordEditPage(recordId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(path: '/ledger/add', builder: (_, __) => const LedgerAddPage()),
    GoRoute(
      path: '/ledger/:id',
      builder: (_, state) =>
          LedgerDetailPage(ledgerId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/ledger/:id/edit',
      builder: (_, state) =>
          LedgerEditPage(ledgerId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/records')) return 1;
    if (location.startsWith('/vehicles')) return 2;
    if (location.startsWith('/ledger')) return 3;
    if (location.startsWith('/settings')) return 4;
    if (location.startsWith('/inventory')) return 4;
    if (location.startsWith('/stats')) return 4;
    if (location.startsWith('/reminders')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BottomNavigationBar(
              currentIndex: index,
              onTap: (i) {
                switch (i) {
                  case 0:
                    context.go('/dashboard');
                  case 1:
                    context.go('/records');
                  case 2:
                    context.go('/vehicles');
                  case 3:
                    context.go('/ledger');
                  case 4:
                    context.go('/settings');
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.space_dashboard_rounded),
                  label: '工作台',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_rounded),
                  label: '工单',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car_rounded),
                  label: '档案',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.payments_rounded),
                  label: '收银',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
