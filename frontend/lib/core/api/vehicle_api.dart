import 'package:image_picker/image_picker.dart';

import '../../models/vehicle.dart';
import 'api_client.dart';

class VehicleApi {
  final _client = apiClientProvider;

  Future<List<Vehicle>> getList({String? search}) async {
    final res = await _client.get(
      '/vehicles',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return (res.data as List).map((j) => Vehicle.fromJson(j)).toList();
  }

  Future<Vehicle> getById(int id) async {
    final res = await _client.get('/vehicles/$id');
    return Vehicle.fromJson(res.data);
  }

  Future<Vehicle> create(Vehicle vehicle) async {
    final res = await _client.post('/vehicles', data: vehicle.toJson());
    return Vehicle.fromJson(res.data);
  }

  Future<Vehicle> update(int id, Vehicle vehicle) async {
    final res = await _client.put('/vehicles/$id', data: vehicle.toJson());
    return Vehicle.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _client.delete('/vehicles/$id');
  }

  Future<String> uploadPhoto(XFile file) async {
    final res = await _client.uploadFile('/upload', file);
    return res.data['url'] ?? '';
  }
}
