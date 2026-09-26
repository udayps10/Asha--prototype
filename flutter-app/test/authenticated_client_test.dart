import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aasha/core/utils/authenticated_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('existing login token is sent without changing the request', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'existing-session'});
    final client = AuthenticatedClient(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer existing-session');
        expect(request.body, '{"name":"Test"}');
        expect(request.headers['Content-Type'], contains('application/json'));
        return http.Response('{}', 200);
      }),
    );
    await client.post(
      Uri.parse('https://aasha.test/api/v1/match'),
      headers: {'Content-Type': 'application/json'},
      body: '{"name":"Test"}',
    );
    client.close();
  });
  test('signed-out requests carry no fabricated authorization', () async {
    SharedPreferences.setMockInitialValues({});
    final client = AuthenticatedClient(
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('', 401);
      }),
    );
    expect(
      (await client.get(Uri.parse('https://aasha.test/api/camps'))).statusCode,
      401,
    );
    client.close();
  });
}
