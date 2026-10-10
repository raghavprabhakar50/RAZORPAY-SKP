import 'dart:async';

import 'package:flutter/material.dart';

import 'third_splash_screen.dart';

class SecondSplashScreen extends StatefulWidget {
  const SecondSplashScreen({super.key});

  @override
  State<SecondSplashScreen> createState() => _SecondSplashScreenState();
}

class _SecondSplashScreenState extends State<SecondSplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _transitionTimer;
  late final AnimationController _mandalaController;

  @override
  void initState() {
    super.initState();
    _mandalaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _transitionTimer = Timer(const Duration(seconds: 4), _openNext);
  }

  void _openNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const ThirdSplashScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _mandalaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xffffffff), Color(0xfffae9cb)],
                stops: [0.18, 1],
              ),
            ),
          ),
          Positioned(
            top: 42,
            right: -89,
            child: RotationTransition(
              turns: _mandalaController,
              child: Opacity(
                opacity: .48,
                child: Image.asset(
                  'assets/images/mandala 2.png',
                  width: 178,
                  height: 178,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: -112,
            bottom: -108,
            child: RotationTransition(
              turns: Tween<double>(
                begin: 0,
                end: -1,
              ).animate(_mandalaController),
              child: Opacity(
                opacity: .7,
                child: Image.asset(
                  'assets/images/mandela ful.png',
                  width: 270,
                  height: 270,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .84, end: 1),
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Builder(
                    builder: (context) {
                      final width = (MediaQuery.sizeOf(context).width * .67)
                          .clamp(240.0, 290.0);
                      return Image.asset(
                        'assets/images/skp logo 2.png',
                        width: width,
                        height: width,
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ),
                const Spacer(flex: 9),
                const _SecondLoadingLine(),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondLoadingLine extends StatelessWidget {
  const _SecondLoadingLine();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 68),
      duration: const Duration(seconds: 4),
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
