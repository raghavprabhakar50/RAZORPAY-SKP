import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/account_store.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';
import 'fourth_splash_screen.dart';

class ThirdSplashScreen extends StatefulWidget {
  const ThirdSplashScreen({super.key});

  @override
  State<ThirdSplashScreen> createState() => _ThirdSplashScreenState();
}

class _ThirdSplashScreenState extends State<ThirdSplashScreen> {
  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_activePage == 0) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } else {
        _openDestination();
      }
    });
  }

  void _openDestination() {
    _autoAdvanceTimer?.cancel();
    final destination = AccountStore.instance.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
  }

  void _handleNext() {
    _autoAdvanceTimer?.cancel();
    if (_activePage == 0) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _openDestination();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSplashLayout(
      onSkip: _openDestination,
      onNext: _handleNext,
      content: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (page) {
          setState(() => _activePage = page);
          _scheduleAutoAdvance();
        },
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
