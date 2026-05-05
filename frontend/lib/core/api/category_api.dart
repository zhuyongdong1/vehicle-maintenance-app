import '../../models/category.dart';
import 'api_client.dart';

class CategoryApi {
  final _client = apiClientProvider;

  Future<List<Category>> getList(String type) async {
    final res = await _client.get(
      '/categories',
      queryParameters: {'type': type},
    );
    return (res.data as List).map((j) => Category.fromJson(j)).toList();
  }

  Future<Category> create(Category category) async {
    final res = await _client.post('/categories', data: category.toJson());
    return Category.fromJson(res.data);
  }

  Future<Category> update(int id, Category category) async {
    final res = await _client.put('/categories/$id', data: category.toJson());
    return Category.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _client.delete('/categories/$id');
  }
}
