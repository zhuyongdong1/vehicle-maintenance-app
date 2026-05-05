import '../../models/dashboard_stats.dart';
import 'api_client.dart';

class DashboardApi {
  final _client = apiClientProvider;

  Future<DashboardStats> getStats() async {
    final res = await _client.get('/dashboard');
    return DashboardStats.fromJson(res.data);
  }
}
