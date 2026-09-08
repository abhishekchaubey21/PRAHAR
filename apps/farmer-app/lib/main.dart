import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/offline_storage.dart';
import 'core/storage/session_store.dart';
import 'core/storage/offline_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'core/api_client.dart';
import 'data/repositories/farmer_profile_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionStore = SecureFileSessionStore();
  final offlineStore = StructuredFileOfflineStore();
  final offlineStorage = OfflineStorageService(store: offlineStore);

  final session = await sessionStore.loadSession();
  final hasValidSession = session != null && session.accessToken.isNotEmpty;
  final initialLanguage = await offlineStorage.loadLanguagePreference();

  // Fast local-only startup check: NEVER block the first UI frame on network/backend I/O.
  // Full remote profile sync is handled asynchronously inside screens after first frame.
  final profileRepo = FarmerProfileRepository(
    apiClient: ApiClient(sessionStore: sessionStore),
    offlineStore: offlineStore,
  );
  final isOnboardingCompleted = hasValidSession
      ? await profileRepo.isOnboardingCompleted(allowRemote: false)
      : false;

  runApp(PraharFarmerApp(
    hasValidSession: hasValidSession,
    isOnboardingCompleted: isOnboardingCompleted,
    sessionStore: sessionStore,
    offlineStore: offlineStore,
    initialLanguage: initialLanguage,
  ));
}

class PraharFarmerApp extends StatelessWidget {
  final bool hasValidSession;
  final bool isOnboardingCompleted;
  final ISessionStore? sessionStore;
  final IOfflineStore? offlineStore;
  final String initialLanguage;
  final Widget? initialHome;

  const PraharFarmerApp({
    super.key,
    this.hasValidSession = false,
    this.isOnboardingCompleted = true,
    this.sessionStore,
    this.offlineStore,
    this.initialLanguage = 'en',
    this.initialHome,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRAHAR Farmer',
      debugShowCheckedModeBanner: false,
      theme: PraharTheme.darkTheme,
      home: initialHome ??
          (hasValidSession
              ? (isOnboardingCompleted
                  ? HomeScreen(
                      sessionStore: sessionStore,
                      offlineStore: offlineStore,
                      initialLanguage: initialLanguage,
                    )
                  : OnboardingScreen(
                      sessionStore: sessionStore,
                      offlineStore: offlineStore,
                      initialLanguage: initialLanguage,
                    ))
              : LoginScreen(
                  sessionStore: sessionStore,
                  offlineStore: offlineStore,
                )),
    );
  }
}
