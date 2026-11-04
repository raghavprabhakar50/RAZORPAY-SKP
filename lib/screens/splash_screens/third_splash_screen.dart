import 'package:flutter/material.dart';

import '../../services/account_store.dart';
import '../login/login_screen.dart';
import '../home/home_screen.dart';
import 'fourth_splash_screen.dart';

class ThirdSplashScreen extends StatefulWidget {
  const ThirdSplashScreen({super.key});

  @override
  State<ThirdSplashScreen> createState() => _ThirdSplashScreenState();
}

class _ThirdSplashScreenState extends State<ThirdSplashScreen> {
  void _openDestination() {
    final destination = AccountStore.instance.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _handleNext() {
    _openDestination();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSplashLayout(
      onSkip: _openDestination,
      onNext: _handleNext,
      content: const OnboardingPageContent(
        title: 'The Nizam Of\nHyderabad',
        subtitle: 'A Legacy Connected To The Jewellers Of',
        activePage: 0,
        showPageDots: false,
        subtitleAboveTitle: true,
      ),
    );
  }
}
