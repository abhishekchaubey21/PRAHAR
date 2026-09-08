import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/auth_service.dart';
import '../core/api_client.dart';
import '../core/storage/session_store.dart';
import '../core/storage/offline_store.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  final FarmerAuthService? authService;
  final ISessionStore? sessionStore;
  final IOfflineStore? offlineStore;
  final String? initialLanguage;

  const RegisterScreen({
    super.key,
    this.authService,
    this.sessionStore,
    this.offlineStore,
    this.initialLanguage,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final FarmerAuthService _authService;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        final hasFarmerId = _authService.currentUser?.farmerId != null &&
            _authService.currentUser!.farmerId!.isNotEmpty;
        if (!hasFarmerId) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => OnboardingScreen(
                authService: _authService,
                apiClient: _authService.apiClient,
                sessionStore: widget.sessionStore,
                offlineStore: widget.offlineStore,
                prefilledName: _fullNameController.text.trim(),
                initialLanguage: widget.initialLanguage ?? 'en',
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                authService: _authService,
                apiClient: _authService.apiClient,
                sessionStore: widget.sessionStore,
                offlineStore: widget.offlineStore,
                initialLanguage: widget.initialLanguage ?? 'en',
              ),
            ),
            (route) => false,
          );
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Registration failed. Please try again.';
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
          _errorMessage = 'Registration Failed (${e.statusCode}): ${e.message}';
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
      appBar: AppBar(
        backgroundColor: PraharTheme.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PraharTheme.textHeading),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'किसान पंजीकरण / Registration',
          style: TextStyle(
            color: PraharTheme.textHeading,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: PraharTheme.borderLight),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PraharTheme.primaryGreen.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: PraharTheme.primaryGreen, width: 2),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        size: 38,
                        color: PraharTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'नया किसान खाता बनाएं',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: PraharTheme.textHeading,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create Your Farmer Account',
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
                  const SizedBox(height: 18),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      key: const Key('register_error_banner'),
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

                  // Full Name Field
                  TextFormField(
                    key: const Key('register_name_field'),
                    controller: _fullNameController,
                    style: const TextStyle(color: PraharTheme.textBody),
                    decoration: const InputDecoration(
                      labelText: 'पूरा नाम / Full Name',
                      prefixIcon: Icon(Icons.person_outline, color: PraharTheme.primaryGreen),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    key: const Key('register_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: PraharTheme.textBody),
                    decoration: const InputDecoration(
                      labelText: 'ईमेल / Email Address',
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
                    key: const Key('register_password_field'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: PraharTheme.textBody),
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
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    key: const Key('register_confirm_password_field'),
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: PraharTheme.textBody),
                    decoration: InputDecoration(
                      labelText: 'पासवर्ड की पुष्टि करें / Confirm Password',
                      prefixIcon: const Icon(Icons.lock_reset, color: PraharTheme.primaryGreen),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: PraharTheme.textMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Confirm password is required';
                      }
                      if (val != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    key: const Key('register_submit_button'),
                    onPressed: _isLoading ? null : _handleRegister,
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
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'पंजीकरण पूरा करें / Complete Registration',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Return to login link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'पहले से खाता है? / Already registered? ',
                        style: TextStyle(color: PraharTheme.textMuted, fontSize: 13),
                      ),
                      TextButton(
                        key: const Key('register_login_link'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'लॉग इन करें / Login',
                          style: TextStyle(
                            color: PraharTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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
