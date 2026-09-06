import 'dart:convert';
import '../../core/api_client.dart';
import '../../domain/models.dart';

/// Repository managing Field Evidence Report generation and export for the Farmer App.
/// Aligned with Phase 6B-3 Specifications:
/// - Authoritative Supabase data only; zero synthetic/demo report data in production paths.
/// - Live backend connectivity is strictly mandatory; NEVER generate reports from offline cache.
/// - NetworkUnavailableException is NOT caught with cached fallback; reports require fresh authoritative data.
/// - ApiExceptions (400, 401, 403, 404, 422, 500) strictly rethrow; never substituted with fake data.
/// - Supports JSON preview and binary PDF generation/download.
class ReportRepository {
  final ApiClient _apiClient;

  ReportRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Fetches authoritative Field Evidence Report as structured JSON
  Future<FieldEvidenceReportModel> getReport({
    required String farmId,
    String? zoneId,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{
      'farm_id': farmId,
      'format': 'json',
    };
    if (zoneId != null && zoneId.isNotEmpty) query['zone_id'] = zoneId;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;

    // Report generation strictly requires live backend connectivity.
    // Offline caching of report generation is prohibited by Phase 6B-3 rules.
    final response = await _apiClient.get(
      '/api/reports/field-evidence',
      queryParams: query,
    );

    if (response != null && response['data'] != null) {
      return FieldEvidenceReportModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw ApiException(500, 'Invalid report response structure');
  }

  /// Explicitly triggers report generation via POST
  Future<FieldEvidenceReportModel> generateReport({
    required String farmId,
    String? zoneId,
    String? from,
    String? to,
    String format = 'json',
  }) async {
    final body = <String, dynamic>{
      'farm_id': farmId,
      'format': format,
    };
    if (zoneId != null && zoneId.isNotEmpty) body['zone_id'] = zoneId;
    if (from != null && from.isNotEmpty) body['from'] = from;
    if (to != null && to.isNotEmpty) body['to'] = to;

    final response = await _apiClient.post(
      '/api/reports/field-evidence/generate',
      body: body,
    );

    if (response != null && response['data'] != null) {
      return FieldEvidenceReportModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw ApiException(500, 'Invalid report generation response structure');
  }

  /// Downloads authoritative PDF bytes directly from backend
  Future<List<int>> downloadPdf({
    required String farmId,
    String? zoneId,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{
      'farm_id': farmId,
      'format': 'pdf',
    };
    if (zoneId != null && zoneId.isNotEmpty) query['zone_id'] = zoneId;
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;

    return await _apiClient.getBytes(
      '/api/reports/field-evidence',
      queryParams: query,
    );
  }

  /// Extracts PDF bytes from report if pdf_base64 is embedded
  List<int>? extractPdfBytesFromReport(FieldEvidenceReportModel report) {
    if (report.pdfBase64 != null && report.pdfBase64!.isNotEmpty) {
      try {
        return base64Decode(report.pdfBase64!);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
