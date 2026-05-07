import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'handlers/vehicle_handler.dart';
import 'handlers/record_handler.dart';
import 'handlers/ledger_handler.dart';
import 'handlers/category_handler.dart';
import 'handlers/ocr_handler.dart';
import 'handlers/upload_handler.dart';
import 'handlers/export_handler.dart';
import 'handlers/dashboard_handler.dart';
import 'handlers/inventory_handler.dart';
import 'handlers/stats_handler.dart';

Router createRouter() {
  final router = Router();

  router.get(
    '/api/health',
    (Request request) => Response.ok('{"status":"ok"}'),
  );

  // Dashboard
  router.get('/api/dashboard', DashboardHandler.getStats);
  router.get('/api/stats/overview', StatsHandler.getOverview);

  // Vehicles
  router.get('/api/vehicles', VehicleHandler.getList);
  router.get('/api/vehicles/<id>', VehicleHandler.getById);
  router.post('/api/vehicles', VehicleHandler.create);
  router.put('/api/vehicles/<id>', VehicleHandler.update);
  router.delete('/api/vehicles/<id>', VehicleHandler.delete);

  // Records
  router.get('/api/records', RecordHandler.getList);
  router.get('/api/records/<id>', RecordHandler.getById);
  router.post('/api/records', RecordHandler.create);
  router.put('/api/records/<id>', RecordHandler.update);
  router.patch('/api/records/<id>/status', RecordHandler.updateStatus);
  router.delete('/api/records/<id>', RecordHandler.delete);

  // Ledger
  router.get('/api/ledger/stats', LedgerHandler.getStats);
  router.get('/api/ledger', LedgerHandler.getList);
  router.get('/api/ledger/<id>', LedgerHandler.getById);
  router.post('/api/ledger', LedgerHandler.create);
  router.put('/api/ledger/<id>', LedgerHandler.update);
  router.delete('/api/ledger/<id>', LedgerHandler.delete);

  // Inventory
  router.get('/api/inventory/stats', InventoryHandler.getStats);
  router.get('/api/inventory/items', InventoryHandler.getItems);
  router.get('/api/inventory/items/<id>', InventoryHandler.getItemById);
  router.post('/api/inventory/items', InventoryHandler.createItem);
  router.put('/api/inventory/items/<id>', InventoryHandler.updateItem);
  router.delete('/api/inventory/items/<id>', InventoryHandler.deleteItem);
  router.get('/api/inventory/transactions', InventoryHandler.getTransactions);
  router.post(
    '/api/inventory/transactions',
    InventoryHandler.createTransaction,
  );

  // Categories
  router.get('/api/categories', CategoryHandler.getList);
  router.post('/api/categories', CategoryHandler.create);
  router.put('/api/categories/<id>', CategoryHandler.update);
  router.delete('/api/categories/<id>', CategoryHandler.delete);

  // OCR
  router.post('/api/ocr/plate', OcrHandler.scanPlate);
  router.post('/api/ocr/vin', OcrHandler.scanVin);

  // Upload
  router.post('/api/upload', UploadHandler.upload);

  // Export
  router.get('/api/export', ExportHandler.exportCsv);

  return router;
}
