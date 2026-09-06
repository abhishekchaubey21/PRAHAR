import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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

/// Structured persistent storage for session tokens.
/// Uses app-private persistent directory (via path_provider) on Android/iOS so
/// session survives app process restarts.
/// Falls back gracefully to local path for desktop and unit tests.
class SecureFileSessionStore implements ISessionStore {
  final String filePath;

  // Process-wide synchronized session cache across instances
  static FarmerSession? _memorySession;

  SecureFileSessionStore({this.filePath = '.prahar_farmer_session.json'});

  Future<File> _resolveFile() async {
    // If an explicit absolute path was given, respect it directly
    if (filePath.startsWith('/') || filePath.contains(':\\') || filePath.contains(':/')) {
      return File(filePath);
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        return File('${dir.path}/$filePath');
      }
    } catch (_) {
      // Fallback in tests or unsupported environments
    }

    return File(filePath);
  }

  @override
  Future<void> saveSession({
    required String accessToken,
    required String? refreshToken,
    required FarmerUser user,
  }) async {
    final session = FarmerSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
    _memorySession = session;

    try {
      final file = await _resolveFile();
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(session.toJson()), flush: true);
    } catch (e) {
      // Memory session remains valid and active even if disk I/O throws
    }
  }

  @override
  Future<FarmerSession?> loadSession() async {
    if (_memorySession != null) {
      return _memorySession;
    }

    try {
      final file = await _resolveFile();
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      _memorySession = FarmerSession.fromJson(json);
      return _memorySession;
    } catch (e) {
      return _memorySession;
    }
  }

  @override
  Future<void> clearSession() async {
    _memorySession = null;
    try {
      final file = await _resolveFile();
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      // Fallback
    }
  }
}
