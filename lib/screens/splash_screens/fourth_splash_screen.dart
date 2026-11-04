import 'package:flutter/material.dart';

class FourthSplashScreen extends StatelessWidget {
  const FourthSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageContent(
      title: 'Hyderabadi Pearls\nExude Elegance',
      subtitle: '',
      activePage: 1,
    );
  }
}

class OnboardingSplashLayout extends StatelessWidget {
  const OnboardingSplashLayout({
    required this.content,
    required this.onSkip,
    required this.onNext,
    super.key,
  });

  final Widget content;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  static const brown = Color(0xff9d6043);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffffffff), Color(0xffffefd2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 700;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(child: content),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: onSkip,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brown,
                                side: const BorderSide(
                                  color: brown,
                                  width: 1.5,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('SKIP'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: FilledButton(
                              onPressed: onNext,
                              style: FilledButton.styleFrom(
                                backgroundColor: brown,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              child: const Text(
                                'NEXT',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 18 : 27),
                    Container(
                      width: 64,
                      height: 3,
                      decoration: BoxDecoration(
                        color: brown,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class OnboardingPageContent extends StatelessWidget {
  const OnboardingPageContent({
    required this.title,
    required this.subtitle,
    required this.activePage,
    this.showPageDots = true,
    this.subtitleAboveTitle = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final int activePage;
  final bool showPageDots;
  final bool subtitleAboveTitle;

  static const _titleBrown = Color(0xff7d4d39);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final illustrationWidth = (constraints.maxWidth * .74).clamp(
          245.0,
          300.0,
        );
        final illustrationHeight = compact ? 174.0 : 205.0;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _JewelleryIllustration(
                width: illustrationWidth,
                height: illustrationHeight,
              ),
              SizedBox(height: compact ? 24 : 38),
              if (subtitleAboveTitle) ...[
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff60534d),
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    height: 1,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _titleBrown,
                  fontFamily: 'Fraunces',
                  fontSize: 30,
                  height: 1.18,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!subtitleAboveTitle) ...[
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff60534d),
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    height: 1,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              SizedBox(height: compact ? 17 : 23),
              if (showPageDots) _PageDots(activePage: activePage),
            ],
          ),
        );
      },
    );
  }
}

class _JewelleryIllustration extends StatelessWidget {
  const _JewelleryIllustration({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/images/old image.webp',
        fit: BoxFit.contain,
        semanticLabel: 'Historic jewellers to H.E.H. The Nizam',
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.activePage});

  final int activePage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (index) {
        final active = index == activePage;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? OnboardingSplashLayout.brown : Colors.transparent,
            border: Border.all(color: OnboardingSplashLayout.brown),
          ),
        );
      }),
    );
  }
}
