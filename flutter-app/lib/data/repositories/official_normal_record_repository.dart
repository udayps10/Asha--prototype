import 'dart:convert';
import '../../core/utils/authenticated_client.dart';
import '../../core/config/api_config.dart';
import '../models/normal_record.dart';

class OfficialNormalRecordRepository {
  final _client = AuthenticatedClient();
  final String _baseUrl = ApiConfig.matchingBaseUrl;

  Future<String> createRecord(NormalRecord record) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/api/normal-records'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': record.name,
            'age': record.age,
            'photoUrl': record.photoUrl,
            'campId': record.campId,
            'campName': record.campName,
            'officerUid': record.officerUid,
            'officerName': record.officerName,
            'officerContact': record.officerContact,
            'status': record.status.name,
            'additionalDetails': record.additionalDetails,
            'foundAt': record.foundAt?.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['id'] ?? '';
    }
    return '';
  }

  Future<List<NormalRecord>> getRecentRecords() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/normal-records/list'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => NormalRecord.fromMap(e['id'], e)).toList();
    }
    return [];
  }

  Future<List<NormalRecord>> searchRecords({
    String? name,
    int? age,
    String? campId,
    NormalRecordStatus? status,
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

  Future<NormalRecord?> getRecordById(String id) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/normal-records/$id'))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return NormalRecord.fromMap(data['id'], data);
    }
    return null;
  }

  Future<void> updateStatus(String recordId, NormalRecordStatus status) async {
    await _client
        .patch(
          Uri.parse('$_baseUrl/api/normal-records/$recordId/status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'status': status.name}),
        )
        .timeout(const Duration(seconds: 15));
  }
}
