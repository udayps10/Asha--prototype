import 'dart:convert';
import '../../core/utils/authenticated_client.dart';
import '../../core/config/api_config.dart';
import '../models/critical_record.dart';

class OfficialCriticalRecordRepository {
  final _client = AuthenticatedClient();
  final String _baseUrl = ApiConfig.matchingBaseUrl;

  Future<void> createRecord(CriticalRecord record) async {
    await _client
        .post(
          Uri.parse('$_baseUrl/api/critical-records'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': record.name,
            'age': record.age,
            'photoUrl': record.photoUrl,
            'clothingPhotoUrl': record.clothingPhotoUrl,
            'lastKnownClothing': record.lastKnownClothing,
            'campId': record.campId,
            'campName': record.campName,
            'officerUid': record.officerUid,
            'officerName': record.officerName,
            'officerContact': record.officerContact,
            'foundLocation': record.foundLocation,
            'foundLatitude': record.foundLatitude,
            'foundLongitude': record.foundLongitude,
            'additionalDetails': record.additionalDetails,
            'status': record.status.name,
            'foundAt': record.foundAt?.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  Future<List<CriticalRecord>> getRecentRecords() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/critical-records/list'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => CriticalRecord.fromMap(e['id'], e)).toList();
    }
    return [];
  }

  Future<CriticalRecord?> getRecordById(String id) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/critical-records/$id'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return CriticalRecord.fromMap(data['id'], data);
    }
    return null;
  }

  Future<List<CriticalRecord>> searchRecords({
    String? name,
    int? age,
    String? campId,
    CriticalRecordStatus? status,
  }) async {
    final records = await getRecentRecords();
    return records.where((r) {
      if (name != null &&
          name.isNotEmpty &&
          !r.name.toLowerCase().contains(name.toLowerCase()))
        return false;
      if (age != null && r.age != age) return false;
      if (campId != null && r.campId != campId) return false;
      if (status != null && r.status != status) return false;
      return true;
    }).toList();
  }

  Future<void> updateStatus(
    String recordId,
    CriticalRecordStatus status,
  ) async {
    await _client
        .patch(
          Uri.parse('$_baseUrl/api/critical-records/$recordId/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': status.name}),
        )
        .timeout(const Duration(seconds: 15));
  }
}
