import 'package:flutter/material.dart';

import '../login/login_screen.dart';
import 'fourth_splash_screen.dart';

class ThirdSplashScreen extends StatefulWidget {
  const ThirdSplashScreen({super.key});

  @override
  State<ThirdSplashScreen> createState() => _ThirdSplashScreenState();
}

class _ThirdSplashScreenState extends State<ThirdSplashScreen> {
  final PageController _pageController = PageController();
  int _activePage = 0;

  void _openLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _handleNext() {
    if (_activePage == 0) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _openLogin();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSplashLayout(
      onSkip: _openLogin,
      onNext: _handleNext,
      content: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (page) => setState(() => _activePage = page),
        children: const [
          OnboardingPageContent(
            title: 'High Quality Pearl\nJewellery',
            subtitle: 'Rings, Occasion Pieces, Pandora & More.',
            activePage: 0,
          ),
          FourthSplashScreen(),
        ],
      ),
    );
  }
}
