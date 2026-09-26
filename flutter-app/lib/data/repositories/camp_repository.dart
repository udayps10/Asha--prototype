import 'dart:convert';
import '../../core/utils/authenticated_client.dart';
import '../../core/config/api_config.dart';
import '../models/camp.dart';

class CampRepository {
  final _client = AuthenticatedClient();
  final String _baseUrl = ApiConfig.matchingBaseUrl;

  Future<void> createCamp(Camp camp) async {
    await _client
        .post(
          Uri.parse('$_baseUrl/api/camps'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': camp.name,
            'locationName': camp.locationName,
            'latitude': camp.latitude,
            'longitude': camp.longitude,
            'contactNumber': camp.contactNumber,
            'officerName': camp.officerName,
            'officerUid': camp.officerUid,
            'active': camp.active,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  Future<List<Camp>> getActiveCamps() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/camps'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Camp.fromMap(e['id'], e)).toList();
    }
    return [];
  }

  Future<List<Camp>> getAllCamps() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/camps'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Camp.fromMap(e['id'], e)).toList();
    }
    return [];
  }

  Future<Camp?> getCampById(String id) async {
    final camps = await getAllCamps();
    try {
      return camps.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateCamp(Camp camp) async {
    await _client
        .put(
          Uri.parse('$_baseUrl/api/camps/${camp.id}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': camp.name,
            'locationName': camp.locationName,
            'latitude': camp.latitude,
            'longitude': camp.longitude,
            'contactNumber': camp.contactNumber,
            'officerName': camp.officerName,
            'officerUid': camp.officerUid,
            'active': camp.active,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }
}
