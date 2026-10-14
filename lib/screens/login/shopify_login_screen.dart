import 'package:flutter/material.dart';

import '../../services/account_store.dart';
import '../../services/shopify_auth_service.dart';
import '../home/home_screen.dart';
import '../signup/signup_screen.dart';

class ShopifyLoginScreen extends StatefulWidget {
  const ShopifyLoginScreen({this.returnToPrevious = false, super.key});

  final bool returnToPrevious;

  @override
  State<ShopifyLoginScreen> createState() => _ShopifyLoginScreenState();
}

class _ShopifyLoginScreenState extends State<ShopifyLoginScreen> {
  static const _brown = Color(0xff945f43);
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = ShopifyAuthService();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final success = await _authService.signIn(email: _emailController.text);
      if (!mounted || !success) return;
      await AccountStore.instance.completeAuthentication(
        fallbackEmail: _emailController.text,
      );
      if (!mounted) return;
      if (widget.returnToPrevious) {
        Navigator.of(context).pop(true);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Login was not completed. Please finish login in the Shopify window.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login  page.png', fit: BoxFit.cover),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: _brown,
                      ),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/skp logo 2.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Sri Krishna Pearls',
                        style: TextStyle(
                          color: Color(0xff7d4d39),
                          fontFamily: 'Fraunces',
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Timeless Elegance',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 72),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        color: Color(0xff7d4d39),
                        fontFamily: 'Fraunces',
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Sign in with your Shopify customer account.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xfffff9f0),
                        hintText: 'Email address',
                        prefixIcon: const Icon(Icons.email, color: _brown),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: _brown),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: _brown),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                            color: _brown,
                            width: 1.7,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Email address is required';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brown,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.login, size: 25),
                        label: Text(
                          _submitting
                              ? 'Opening Shopify...'
                              : 'Login with Shopify',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SignupScreen(),
                                ),
                              ),
                        style: TextButton.styleFrom(foregroundColor: _brown),
                        child: const Text('New customer? Create account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
