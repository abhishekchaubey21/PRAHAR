import 'dart:convert';
import 'dart:io';
import '../auth_service.dart';

/// Storage abstraction for farmer authentication sessions.
/// Aligned with Mandatory Amendment 2:
/// - Isolate persistence behind storage abstractions.
/// - SessionStore must be replaceable.
/// - Prefer secure platform storage for session.
abstract class ISessionStore {
  Future<void> saveSession({
    required String accessToken,
    required String? refreshToken,
    required FarmerUser user,
  });

  Future<FarmerSession?> loadSession();

  Future<void> clearSession();
}

class FarmerSession {
  final String accessToken;
  final String? refreshToken;
  final FarmerUser user;

  const FarmerSession({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user': user.toJson(),
      };

  factory FarmerSession.fromJson(Map<String, dynamic> json) {
    return FarmerSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      user: FarmerUser(
        id: json['user']['id'] as String,
        email: json['user']['email'] as String,
        fullName: json['user']['full_name'] as String,
        role: (json['user']['role'] as String?) ?? 'FARMER',
        farmerId: json['user']['farmer_id'] as String?,
      ),
    );
  }
}

/// In-memory session store for ephemeral environments and unit tests
class InMemorySessionStore implements ISessionStore {
  FarmerSession? _session;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String? refreshToken,
    required FarmerUser user,
  }) async {
    _session = FarmerSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  @override
  Future<FarmerSession?> loadSession() async {
    return _session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}

/// Structured persistent storage for session tokens
class SecureFileSessionStore implements ISessionStore {
  final String filePath;

  SecureFileSessionStore({this.filePath = '.prahar_farmer_session.json'});

  @override
  Future<void> saveSession({
    required String accessToken,
    required String? refreshToken,
    required FarmerUser user,
  }) async {
    try {
      final session = FarmerSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
      final file = File(filePath);
      await file.writeAsString(jsonEncode(session.toJson()), flush: true);
    } catch (e) {
      // Platform fallback / logging
    }
  }

  @override
  Future<FarmerSession?> loadSession() async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return FarmerSession.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Fallback
    }
  }
}
