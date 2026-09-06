import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/offline_storage.dart';
import 'core/storage/session_store.dart';
import 'core/storage/offline_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionStore = SecureFileSessionStore();
  final offlineStore = StructuredFileOfflineStore();
  final offlineStorage = OfflineStorageService(store: offlineStore);

  final session = await sessionStore.loadSession();
  final hasValidSession = session != null && session.accessToken.isNotEmpty;
  final initialLanguage = await offlineStorage.loadLanguagePreference();

  runApp(PraharFarmerApp(
    hasValidSession: hasValidSession,
    sessionStore: sessionStore,
    offlineStore: offlineStore,
    initialLanguage: initialLanguage,
  ));
}

class PraharFarmerApp extends StatelessWidget {
  final bool hasValidSession;
  final ISessionStore? sessionStore;
  final IOfflineStore? offlineStore;
  final String initialLanguage;
  final Widget? initialHome;

  const PraharFarmerApp({
    super.key,
    this.hasValidSession = false,
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
              ? HomeScreen(
                  sessionStore: sessionStore,
                  offlineStore: offlineStore,
                  initialLanguage: initialLanguage,
                )
              : LoginScreen(
                  sessionStore: sessionStore,
                  offlineStore: offlineStore,
                )),
    );
  }
}
