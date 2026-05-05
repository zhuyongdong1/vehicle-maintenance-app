import 'package:test/test.dart';
import 'package:shelf/shelf.dart';
import 'package:backend/router.dart';

void main() {
  late Handler handler;

  setUp(() async {
    handler = createRouter().call;
  });

  test('Health', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/health')),
    );
    expect(response.statusCode, 200);
    expect(await response.readAsString(), '{"status":"ok"}');
  });

  test('404', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/foobar')),
    );
    expect(response.statusCode, 404);
  });
}
