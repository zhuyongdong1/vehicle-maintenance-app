import '../../models/inventory.dart';
import 'api_client.dart';

class InventoryApi {
  final _client = apiClientProvider;

  Future<List<InventoryItem>> getItems({
    String? search,
    String? category,
    bool lowStock = false,
  }) async {
    final res = await _client.get(
      '/inventory/items',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (category != null && category.isNotEmpty) 'category': category,
        if (lowStock) 'low_stock': 'true',
      },
    );
    return (res.data as List).map((j) => InventoryItem.fromJson(j)).toList();
  }

  Future<InventoryItem> createItem(InventoryItem item) async {
    final res = await _client.post('/inventory/items', data: item.toJson());
    return InventoryItem.fromJson(res.data);
  }

  Future<InventoryItem> updateItem(int id, InventoryItem item) async {
    final res = await _client.put('/inventory/items/$id', data: item.toJson());
    return InventoryItem.fromJson(res.data);
  }

  Future<void> deleteItem(int id) async {
    await _client.delete('/inventory/items/$id');
  }

  Future<List<InventoryTransaction>> getTransactions({int? itemId}) async {
    final res = await _client.get(
      '/inventory/transactions',
      queryParameters: {if (itemId != null) 'item_id': itemId},
    );
    return (res.data as List)
        .map((j) => InventoryTransaction.fromJson(j))
        .toList();
  }

  Future<InventoryTransaction> createTransaction({
    required int itemId,
    required String type,
    required int quantity,
    double unitPrice = 0,
    String? notes,
  }) async {
    final res = await _client.post(
      '/inventory/transactions',
      data: {
        'item_id': itemId,
        'type': type,
        'quantity': quantity,
        'unit_price': unitPrice,
        'notes': notes,
      },
    );
    return InventoryTransaction.fromJson(res.data);
  }

  Future<InventoryStats> getStats() async {
    final res = await _client.get('/inventory/stats');
    return InventoryStats.fromJson(res.data);
  }
}
