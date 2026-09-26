import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../../../core/utils/authenticated_client.dart';
import '../models/match_request.dart';
import '../models/match_response.dart';

/// Contract for the future protected REST matching backend.
///
/// Uses the local FastAPI mock in development. The base URL is centralized in
/// [ApiConfig] and can be replaced without changing this service.
abstract interface class MatchApiService {
  Future<MatchResponse> findMatches(MatchRequest request);

  Future<MatchResponse> getMoreMatches(MatchPageRequest request);
}

class HttpMatchApiService implements MatchApiService {
  HttpMatchApiService({http.Client? client, String? baseUrl})
    : _client = AuthenticatedClient(client: client),
      _baseUrl = (baseUrl ?? ApiConfig.matchingBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      ) {
    if (kDebugMode) {
      debugPrint('[MATCH API] base URL=$_baseUrl');
    }
  }

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 90);

  @override
  Future<MatchResponse> findMatches(MatchRequest request) =>
      _post('/api/v1/match', request.toJson());

  @override
  Future<MatchResponse> getMoreMatches(MatchPageRequest request) =>
      _post('/api/v1/match/more', request.toJson());

  Future<MatchResponse> _post(String path, Map<String, dynamic> body) async {
    final matchUrl = '$_baseUrl$path';
    debugPrint('[MATCH DEBUG] baseUrl = $_baseUrl');
    debugPrint('[MATCH DEBUG] matchUrl = $matchUrl');
    debugPrint('[MATCH DEBUG] requestCreated = true');
    debugPrint('[MATCH DEBUG] requestJson = ${jsonEncode(body)}');
    try {
      debugPrint('[MATCH DEBUG] requestStarted = true');
      final response = await _client
          .post(
            Uri.parse(matchUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      debugPrint('[MATCH DEBUG] responseReceived = true');
      debugPrint('[MATCH DEBUG] responseStatus = ${response.statusCode}');
      debugPrint('[MATCH DEBUG] responseBodyLength = ${response.body.length}');

      if (kDebugMode) {
        debugPrint('[MATCH API] $path status=${response.statusCode}');
        debugPrint('[MATCH API] response=${response.body}');
      }

      Map<String, dynamic>? decoded;
      if (response.body.trim().isNotEmpty) {
        debugPrint('[MATCH DEBUG] jsonParsingStarted = true');
        final value = jsonDecode(response.body);
        if (value is! Map)
          throw const FormatException('Response is not an object');
        decoded = Map<String, dynamic>.from(value);
        debugPrint('[MATCH DEBUG] jsonParsingCompleted = true');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MatchApiException.fromResponse(response.statusCode, decoded);
      }
      if (decoded == null) {
        throw const FormatException('Response body is empty');
      }
      try {
        final result = MatchResponse.fromJson(decoded);
        debugPrint('[MATCH DEBUG] repositoryCompleted = true');
        return result;
      } on FormatException catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[MATCH API] response parsing failed: $error');
          debugPrint('$stackTrace');
        }
        rethrow;
      }
    } on MatchApiException catch (e) {
      debugPrint('[MATCH DEBUG] exception = MatchApiException: $e');
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('[MATCH DEBUG] exception = TimeoutException: $e');
      throw MatchApiException(
        statusCode: 0,
        code: 'timeout',
        message: 'Matching request timed out. Please try again.',
      );
    } on SocketException catch (e) {
      debugPrint('[MATCH DEBUG] exception = SocketException: $e');
      throw MatchApiException(
        statusCode: 0,
        code: 'connection_failed',
        message:
            'Matching service is unavailable. Please check your connection.',
      );
    } on FormatException catch (error, stackTrace) {
      debugPrint('[MATCH DEBUG] exception = FormatException: $error');
      if (kDebugMode) {
        debugPrint('[MATCH API] invalid response field/type: $error');
        debugPrint('$stackTrace');
      }
      throw MatchApiException(
        statusCode: 0,
        code: 'invalid_response',
        message: 'The matching service returned an invalid response.',
      );
    } catch (e) {
      debugPrint('[MATCH DEBUG] exception = Unknown: $e');
      throw MatchApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Unable to contact the matching service. Please try again.',
      );
    }
  }
}

class MatchApiException implements Exception {
  MatchApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String message;
  final String? code;

  factory MatchApiException.fromResponse(
    int statusCode,
    Map<String, dynamic>? body,
  ) {
    final error = body?['error'];
    final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
    return MatchApiException(
      statusCode: statusCode,
      code: errorMap?['code'] as String?,
      message: errorMap?['message'] as String? ?? _defaultMessage(statusCode),
    );
  }

  static String _defaultMessage(int statusCode) => switch (statusCode) {
    400 => 'Invalid request',
    401 => 'Authentication required',
    403 => 'Not allowed',
    404 => 'Matching service or resource not found',
    429 => 'Too many requests',
    _ => 'Matching service unavailable',
  };

  @override
  String toString() => 'MatchApiException($statusCode): $message';
}
