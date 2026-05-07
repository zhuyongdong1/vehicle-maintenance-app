import '../../models/record.dart';
import 'api_client.dart';

class RecordApi {
  final _client = apiClientProvider;

  Future<List<Record>> getList({
    int? categoryId,
    String? search,
    int? vehicleId,
  }) async {
    final res = await _client.get(
      '/records',
      queryParameters: {
        if (categoryId != null) 'category_id': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (vehicleId != null) 'vehicle_id': vehicleId,
      },
    );
    return (res.data as List).map((j) => Record.fromJson(j)).toList();
  }

  Future<Record> getById(int id) async {
    final res = await _client.get('/records/$id');
    return Record.fromJson(res.data);
  }

  Future<Record> create(Record record) async {
    final res = await _client.post('/records', data: record.toJson());
    return Record.fromJson(res.data);
  }

  Future<Record> update(int id, Record record) async {
    final res = await _client.put('/records/$id', data: record.toJson());
    return Record.fromJson(res.data);
  }

  Future<Record> updateStatus(int id, String status) async {
    final res = await _client.patch(
      '/records/$id/status',
      data: {'status': status},
    );
    return Record.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _client.delete('/records/$id');
  }
}
