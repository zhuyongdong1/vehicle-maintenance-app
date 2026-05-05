import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

class OcrApi {
  final _client = apiClientProvider;

  Future<String> scanPlate(XFile image) async {
    final res = await _client.uploadFile('/ocr/plate', image);
    return res.data['plate_number'] ?? '';
  }

  Future<String> scanVin(XFile image) async {
    final res = await _client.uploadFile('/ocr/vin', image);
    return res.data['vin'] ?? '';
  }
}
