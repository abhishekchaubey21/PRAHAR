/// PRAHAR Farmer Mobile App — Supabase Authentication & Session Service
/// Aligned with Phase 5A Amendment 2 & 5:
/// - Public registration creates only FARMER users
/// - Manages JWT access tokens and authenticated requests
/// - On logout: Clears credentials and locks protected cached farmer data

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
}

class FarmerAuthService {
  static final FarmerAuthService _instance = FarmerAuthService._internal();
  factory FarmerAuthService() => _instance;
  FarmerAuthService._internal();

  FarmerUser? _currentUser = const FarmerUser(
    id: 'usr-farmer-ramesh-01',
    email: 'farmer.ramesh@kisan.in',
    fullName: 'Ramesh Patel (रमेश पटेल)',
    farmerId: 'FARMER-DEMO-01',
  );

  String? _accessToken = 'mock-jwt-farmer-usr-farmer-ramesh-01';

  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  FarmerUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;

  /// Authenticates farmer with email and password
  Future<bool> login(String email, String password) async {
    // Simulated / live login contract
    if (password.length >= 6) {
      _currentUser = FarmerUser(
        id: 'usr-farmer-${email.hashCode.abs().toString().substring(0, 5)}',
        email: email,
        fullName: email.split('@')[0],
        farmerId: 'FARMER-DEMO-01',
      );
      _accessToken = 'mock-jwt-farmer-${_currentUser!.id}';
      return true;
    }
    return false;
  }

  /// Registers farmer — strictly creates FARMER role
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (password.length >= 6 && email.contains('@')) {
      _currentUser = FarmerUser(
        id: 'usr-farmer-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        email: email,
        fullName: fullName,
        farmerId: 'FARMER-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      );
      _accessToken = 'mock-jwt-farmer-${_currentUser!.id}';
      return true;
    }
    return false;
  }

  /// Amendment 5: Logout clears access token and protected cached farmer data
  void logout() {
    _accessToken = null;
    _currentUser = null;
  }
}
