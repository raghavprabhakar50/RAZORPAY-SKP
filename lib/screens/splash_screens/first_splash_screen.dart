import 'dart:async';

import 'package:flutter/material.dart';

import 'second_splash_screen.dart';

class FirstSplashScreen extends StatefulWidget {
  const FirstSplashScreen({super.key});

  @override
  State<FirstSplashScreen> createState() => _FirstSplashScreenState();
}

class _FirstSplashScreenState extends State<FirstSplashScreen> {
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _transitionTimer = Timer(const Duration(seconds: 2), _openNext);
  }

  void _openNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const SecondSplashScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _FirstSplashBackground(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .82, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = (MediaQuery.sizeOf(context).width * .68).clamp(
                235.0,
                285.0,
              );
              return Image.asset(
                'assets/images/skp logo 1.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FirstSplashBackground extends StatelessWidget {
  const _FirstSplashBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/splash bg.png', fit: BoxFit.cover),
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 8),
              Center(child: child),
              const Spacer(flex: 9),
              const _FirstLoadingLine(),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ],
    );
  }
}

class _FirstLoadingLine extends StatelessWidget {
  const _FirstLoadingLine();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 68),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOutCubic,
      builder: (_, width, _) => Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          color: const Color(0xff8c5133),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
