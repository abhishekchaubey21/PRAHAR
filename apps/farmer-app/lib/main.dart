import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PraharFarmerApp());
}

class PraharFarmerApp extends StatelessWidget {
  const PraharFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRAHAR Farmer',
      debugShowCheckedModeBanner: false,
      theme: PraharTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
