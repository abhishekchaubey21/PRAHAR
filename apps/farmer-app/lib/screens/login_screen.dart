import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/auth_service.dart';
import '../core/api_client.dart';
import '../core/storage/session_store.dart';
import '../core/storage/offline_store.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'onboarding_screen.dart';
import '../data/repositories/farmer_profile_repository.dart';

class LoginScreen extends StatefulWidget {
  final FarmerAuthService? authService;
  final ISessionStore? sessionStore;
  final IOfflineStore? offlineStore;
  final String? initialLanguage;

  const LoginScreen({
    super.key,
    this.authService,
    this.sessionStore,
    this.offlineStore,
    this.initialLanguage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final FarmerAuthService _authService;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ??
        FarmerAuthService(
          sessionStore: widget.sessionStore ?? SecureFileSessionStore(),
        );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        final profileRepo = FarmerProfileRepository(
          apiClient: _authService.apiClient,
          offlineStore: widget.offlineStore ?? StructuredFileOfflineStore(),
        );
        final isCompleted = await profileRepo.isOnboardingCompleted();
        final hasFarmerId = _authService.currentUser?.farmerId != null &&
            _authService.currentUser!.farmerId!.isNotEmpty;

        if (!mounted) return;
        if (!isCompleted && !hasFarmerId) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OnboardingScreen(
                authService: _authService,
                apiClient: _authService.apiClient,
                sessionStore: widget.sessionStore,
                offlineStore: widget.offlineStore,
                profileRepository: profileRepo,
                initialLanguage: widget.initialLanguage ?? 'en',
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                authService: _authService,
                apiClient: _authService.apiClient,
                sessionStore: widget.sessionStore,
                offlineStore: widget.offlineStore,
                initialLanguage: widget.initialLanguage ?? 'en',
              ),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Invalid email or password. Please try again.';
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network Error: Unable to reach PRAHAR gateway. Please check your internet connection.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication Failed (${e.statusCode}): ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PraharTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand & Logo Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PraharTheme.primaryGreen.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: PraharTheme.primaryGreen, width: 2),
                      ),
                      child: const Icon(
                        Icons.agriculture,
                        size: 48,
                        color: PraharTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PRAHAR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: PraharTheme.textHeading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'स्मार्ट कृषि निगरानी • Field Intelligence',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: PraharTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // SIH & Institute Identity Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: PraharTheme.cardBgGreen,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PraharTheme.borderGreen),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          'SIH 2026 • Team KYROS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: PraharTheme.darkGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Vivekananda Institute of Professional Studies',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: PraharTheme.textBody,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      key: const Key('login_error_banner'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertRoseLight,
                        border: Border.all(color: PraharTheme.alertRose),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: PraharTheme.alertRose, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: PraharTheme.alertRose, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Email Field
                  TextFormField(
                    key: const Key('login_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ईमेल / Email',
                      prefixIcon: Icon(Icons.email_outlined, color: PraharTheme.primaryGreen),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!val.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    key: const Key('login_password_field'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'पासवर्ड / Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: PraharTheme.primaryGreen),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: PraharTheme.textMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Password is required';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    key: const Key('login_submit_button'),
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'लॉग इन करें / Sign In',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Link to Register
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'खाता नहीं है? / No account? ',
                        style: TextStyle(color: PraharTheme.textMuted, fontSize: 13),
                      ),
                      TextButton(
                        key: const Key('login_register_link'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RegisterScreen(
                                authService: _authService,
                                offlineStore: widget.offlineStore,
                                initialLanguage: widget.initialLanguage,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'पंजीकरण करें / Register',
                          style: TextStyle(
                            color: PraharTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Demo Presentation Quick Login
                  OutlinedButton.icon(
                    key: const Key('login_demo_quick_button'),
                    icon: const Icon(Icons.flash_on, size: 16, color: PraharTheme.alertAmber),
                    label: const Text(
                      'डेमो किसान लॉगिन / Quick Demo Login (Ramesh)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PraharTheme.darkGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: PraharTheme.cardBgGreen,
                      side: const BorderSide(color: PraharTheme.borderGreen),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _emailController.text = 'farmer.ramesh@kisan.in';
                              _passwordController.text = 'Kisan@123';
                            });
                            _handleLogin();
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // SIH identity footer
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: const BoxDecoration(
          color: PraharTheme.primaryGreenLight,
          border: Border(top: BorderSide(color: PraharTheme.borderGreen)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.agriculture, color: PraharTheme.primaryGreen, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'PRAHAR  |  SIH 2026 • Team KYROS  |  Vivekananda Institute of Professional Studies',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: PraharTheme.darkGreen, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
