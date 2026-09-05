/// PRAHAR Farmer Mobile App — Supabase Authentication & Session Service
/// Aligned with Phase 5A & 5B:
/// - Authenticated HTTP / JWT integration with PRAHAR Gateway
/// - Storage abstraction via ISessionStore
/// - Public registration creates only FARMER users
/// - Manages JWT access tokens and authenticated requests
/// - On logout: Clears credentials and locks protected cached farmer data

import 'dart:async';
import 'api_client.dart';
import 'storage/session_store.dart';

class FarmerUser {
  final String id;
  final String email;
  final String fullName;
  final String role; // Always 'FARMER'
  final String? farmerId;

  const FarmerUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = 'FARMER',
    this.farmerId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'farmer_id': farmerId,
      };

  factory FarmerUser.fromJson(Map<String, dynamic> json) {
    return FarmerUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: (json['full_name'] ?? json['fullName'] ?? '') as String,
      role: (json['role'] as String?) ?? 'FARMER',
      farmerId: json['farmer_id'] as String?,
    );
  }
}

typedef AuthService = FarmerAuthService;

class FarmerAuthService {
  static FarmerAuthService? _instance;
  final ISessionStore _sessionStore;
  final ApiClient _apiClient;

  FarmerUser? _currentUser;
  String? _accessToken;

  factory FarmerAuthService({
    ISessionStore? sessionStore,
    ApiClient? apiClient,
  }) {
    if (_instance == null || sessionStore != null || apiClient != null) {
      final store = sessionStore ?? SecureFileSessionStore();
      final client = apiClient ?? ApiClient(sessionStore: store);
      _instance = FarmerAuthService._internal(store, client);
    }
    return _instance!;
  }

  FarmerAuthService._internal(this._sessionStore, this._apiClient);

  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  FarmerUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  ISessionStore get sessionStore => _sessionStore;
  ApiClient get apiClient => _apiClient;

  /// Helper for test fixtures to explicitly set a test session
  void setTestSession({required String token, required FarmerUser user}) {
    _accessToken = token;
    _currentUser = user;
  }

  /// Initializes session from storage
  Future<void> init() async {
    final session = await _sessionStore.loadSession();
    if (session != null) {
      _accessToken = session.accessToken;
      _currentUser = session.user;
    }
  }

  /// Authenticates farmer with email and password against Gateway / Supabase Auth.
  /// Throws NetworkUnavailableException on genuine network issues.
  /// Throws ApiException on 401/403/400/500 errors.
  Future<bool> login(String email, String password) async {
    final response = await _apiClient.post('/api/auth/login', body: {
      'email': email,
      'password': password,
    });

    if (response != null) {
      final sessionMap = (response['session'] as Map<String, dynamic>?) ?? response;
      final token = (sessionMap['access_token'] ?? sessionMap['token']) as String?;

      if (token != null) {
        final userMap = sessionMap['user'] as Map<String, dynamic>? ?? {};
        final user = FarmerUser(
          id: userMap['id'] as String? ?? 'usr-farmer-${email.hashCode.abs()}',
          email: userMap['email'] as String? ?? email,
          fullName: userMap['full_name'] as String? ?? email.split('@')[0],
          role: 'FARMER',
          farmerId: userMap['farmer_id'] as String? ?? 'FARMER-DEMO-01',
        );

        _accessToken = token;
        _currentUser = user;

        await _sessionStore.saveSession(
          accessToken: token,
          refreshToken: sessionMap['refresh_token'] as String?,
          user: user,
        );
        return true;
      }
    }

    return false;
  }

  /// Registers farmer — strictly creates FARMER role via Gateway / Supabase Auth.
  /// Never sends a client-selected role.
  /// Throws NetworkUnavailableException on genuine network issues.
  /// Throws ApiException on backend errors.
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _apiClient.post('/api/auth/register', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
    });

    if (response != null) {
      final sessionMap = (response['session'] as Map<String, dynamic>?) ?? response;
      final token = (sessionMap['access_token'] ?? sessionMap['token']) as String?;

      if (token != null) {
        final userMap = sessionMap['user'] as Map<String, dynamic>? ?? {};
        final user = FarmerUser(
          id: userMap['id'] as String? ?? 'usr-farmer-${email.hashCode.abs()}',
          email: userMap['email'] as String? ?? email,
          fullName: fullName,
          role: 'FARMER',
          farmerId: userMap['farmer_id'] as String?,
        );

        _accessToken = token;
        _currentUser = user;

        await _sessionStore.saveSession(
          accessToken: token,
          refreshToken: sessionMap['refresh_token'] as String?,
          user: user,
        );
        return true;
      }
    }

    return false;
  }

  /// Logout clears access token, current user, and stored session
  Future<void> logout() async {
    try {
      await _apiClient.post('/api/auth/logout');
    } catch (_) {
      // Best-effort remote notification
    }
    _accessToken = null;
    _currentUser = null;
    await _sessionStore.clearSession();
  }
}
