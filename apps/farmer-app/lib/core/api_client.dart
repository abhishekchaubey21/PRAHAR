import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'storage/session_store.dart';

/// Exception thrown when network connectivity is genuinely unavailable
class NetworkUnavailableException implements Exception {
  final String message;
  final Object? cause;

  const NetworkUnavailableException(this.message, [this.cause]);

  @override
  String toString() => 'NetworkUnavailableException: $message';
}

/// Exception thrown when the backend returns an error response (4xx, 5xx)
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  const ApiException(this.statusCode, this.message, [this.details]);

  @override
  String toString() => 'ApiException ($statusCode): $message';
}

/// Authenticated API Client for Farmer Mobile App.
/// Aligned with Mandatory Amendment 1:
/// - Supabase / Gateway authoritative whenever online.
/// - Network failures throw NetworkUnavailableException (eligible for offline cache fallback).
/// - Auth / Validation / 4xx / 5xx errors throw ApiException (NEVER fall back silently).
class ApiClient {
  final String baseUrl;
  final ISessionStore sessionStore;
  final http.Client _httpClient;

  ApiClient({
    this.baseUrl = 'http://127.0.0.1:3001',
    required this.sessionStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final session = await sessionStore.loadSession();
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    return headers;
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: {...uri.queryParameters, ...queryParams});
    }
    return uri;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams, Duration timeout = const Duration(seconds: 10)}) async {
    final uri = _buildUri(path, queryParams);
    http.Response response;

    try {
      final headers = await _buildHeaders();
      response = await _httpClient.get(uri, headers: headers).timeout(timeout);
    } on SocketException catch (e) {
      throw NetworkUnavailableException('Failed to reach backend at $uri (SocketException)', e);
    } on TimeoutException catch (e) {
      throw NetworkUnavailableException('Request to $uri timed out after $timeout', e);
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException('Client connection error at $uri', e);
    } catch (e) {
      if (e is NetworkUnavailableException || e is ApiException) rethrow;
      throw NetworkUnavailableException('Unexpected network error reaching $uri: $e', e);
    }

    return _processResponse(response);
  }

  Future<dynamic> post(String path, {dynamic body, Duration timeout = const Duration(seconds: 10)}) async {
    final uri = _buildUri(path);
    http.Response response;

    try {
      final headers = await _buildHeaders();
      final bodyStr = body != null ? jsonEncode(body) : null;
      response = await _httpClient.post(uri, headers: headers, body: bodyStr).timeout(timeout);
    } on SocketException catch (e) {
      throw NetworkUnavailableException('Failed to reach backend at $uri (SocketException)', e);
    } on TimeoutException catch (e) {
      throw NetworkUnavailableException('Request to $uri timed out after $timeout', e);
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException('Client connection error at $uri', e);
    } catch (e) {
      if (e is NetworkUnavailableException || e is ApiException) rethrow;
      throw NetworkUnavailableException('Unexpected network error reaching $uri: $e', e);
    }

    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final errorMessage = decoded is Map && decoded['error'] != null
        ? decoded['error'].toString()
        : decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : 'HTTP Error ${response.statusCode}';

    throw ApiException(response.statusCode, errorMessage, decoded);
  }
}
