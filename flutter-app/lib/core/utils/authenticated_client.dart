import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Adds the existing session token; request payloads and response parsing are unchanged.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? _storedToken;
  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  static Future<String?> _storedToken() async =>
      (await SharedPreferences.getInstance()).getString('auth_token');
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
