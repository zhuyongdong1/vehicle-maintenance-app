import '../../models/business_stats.dart';
import 'api_client.dart';

class StatsApi {
  final _client = apiClientProvider;

  Future<BusinessStats> getOverview({int days = 30}) async {
    final res = await _client.get(
      '/stats/overview',
      queryParameters: {'days': days},
    );
    return BusinessStats.fromJson(res.data);
  }
}
