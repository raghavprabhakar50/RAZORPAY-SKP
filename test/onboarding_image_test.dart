import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sri_krishna_pearls_mobile/screens/splash_screens/fourth_splash_screen.dart';

void main() {
  testWidgets(
    'both onboarding pages use the full historic image without cropping',
    (tester) async {
      for (final page in [0, 1]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OnboardingPageContent(
                title: 'Test',
                subtitle: 'Test subtitle',
                activePage: page,
              ),
            ),
          ),
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(
          (image.image as AssetImage).assetName,
          'assets/images/old image.webp',
        );
        expect(image.fit, BoxFit.contain);
      }
    },
  );
}
