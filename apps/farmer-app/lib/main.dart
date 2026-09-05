import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/storage/session_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessionStore = SecureFileSessionStore();
  final session = await sessionStore.loadSession();
  final hasValidSession = session != null && session.accessToken.isNotEmpty;

  runApp(PraharFarmerApp(
    hasValidSession: hasValidSession,
    sessionStore: sessionStore,
  ));
}

class PraharFarmerApp extends StatelessWidget {
  final bool hasValidSession;
  final ISessionStore? sessionStore;
  final Widget? initialHome;

  const PraharFarmerApp({
    super.key,
    this.hasValidSession = false,
    this.sessionStore,
    this.initialHome,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRAHAR Farmer',
      debugShowCheckedModeBanner: false,
      theme: PraharTheme.darkTheme,
      home: initialHome ?? (hasValidSession ? const HomeScreen() : const LoginScreen()),
    );
  }
}
