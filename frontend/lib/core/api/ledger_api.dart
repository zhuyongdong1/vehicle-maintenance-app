import '../../models/ledger.dart';
import 'api_client.dart';

class LedgerApi {
  final _client = apiClientProvider;

  Future<List<Ledger>> getList({
    String? type,
    int? categoryId,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    final res = await _client.get(
      '/ledger',
      queryParameters: {
        if (type != null) 'type': type,
        if (categoryId != null) 'category_id': categoryId,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return (res.data as List).map((j) => Ledger.fromJson(j)).toList();
  }

  Future<Ledger> getById(int id) async {
    final res = await _client.get('/ledger/$id');
    return Ledger.fromJson(res.data);
  }

  Future<Ledger> create(Ledger ledger) async {
    final res = await _client.post('/ledger', data: ledger.toJson());
    return Ledger.fromJson(res.data);
  }

  Future<Ledger> update(int id, Ledger ledger) async {
    final res = await _client.put('/ledger/$id', data: ledger.toJson());
    return Ledger.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _client.delete('/ledger/$id');
  }

  Future<Map<String, dynamic>> getStats({String? period}) async {
    final res = await _client.get(
      '/ledger/stats',
      queryParameters: {if (period != null) 'period': period},
    );
    return res.data;
  }
}
