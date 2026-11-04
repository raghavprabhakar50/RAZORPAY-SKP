import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/account_store.dart';
import '../home/home_screen.dart';
import '../signup/signup_screen.dart';
import 'shopify_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _brown = Color(0xff945f43);
  void _openSignup() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SignupScreen()));
  }

  void _openLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ShopifyLoginScreen()));
  }

  void _openHome({bool guest = false}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => HomeScreen(guest: guest)),
      (_) => false,
    );
  }

  void _continueAsGuest() {
    unawaited(AccountStore.instance.continueAsGuest());
    _openHome(guest: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login  page.png', fit: BoxFit.cover),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: constraints.maxHeight * .08),
                        Center(
                          child: Image.asset(
                            'assets/images/skp logo 2.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Sri Krishna Pearls',
                            style: TextStyle(
                              color: Color(0xff7d4d39),
                              fontFamily: 'Fraunces',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: constraints.maxHeight * .11),
                        const Text(
                          'Login / Sign Up',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 18),
                        _AuthButton(
                          label: 'New customer signup',
                          icon: Icons.person_add_alt_1,
                          filled: true,
                          onPressed: _openSignup,
                        ),
                        const SizedBox(height: 18),
                        _AuthButton(
                          label: 'Continue with Us',
                          icon: Icons.login,
                          onPressed: _openLogin,
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: TextButton.icon(
                            onPressed: _continueAsGuest,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xff5e514b),
                            ),
                            icon: const Icon(
                              Icons.storefront,
                              color: _brown,
                              size: 26,
                            ),
                            label: const Text('Continue as Guest'),
                          ),
                        ),
                        const SizedBox(height: 34),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : _LoginScreenState._brown;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _LoginScreenState._brown,
                foregroundColor: foreground,
                shape: const StadiumBorder(),
              ),
              icon: Icon(icon, size: 25),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                side: const BorderSide(
                  color: _LoginScreenState._brown,
                  width: 1.5,
                ),
                shape: const StadiumBorder(),
              ),
              icon: Icon(icon, size: 25),
              label: Text(label),
            ),
    );
  }
}
