import 'package:flutter/material.dart';

import '../../services/account_store.dart';
import '../../services/shopify_auth_service.dart';
import '../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _brown = Color(0xff945f43);
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final ShopifyAuthService _authService = ShopifyAuthService();
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _signupWithShopify() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final success = await _authService.signUp(
        email: _emailController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      if (success) {
        await AccountStore.instance.completeAuthentication(
          fallbackEmail: _emailController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signup was not completed. Please try again in the Shopify window.',
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: constraints.maxHeight * .045),
                          Center(
                            child: Image.asset(
                              'assets/images/skp logo 2.png',
                              width: 118,
                              height: 118,
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
                          const SizedBox(height: 4),
                          const Center(
                            child: Text(
                              'Timeless Elegance',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * .065),
                          const Text(
                            'Create new account',
                            style: TextStyle(
                              color: Color(0xff7d4d39),
                              fontFamily: 'Fraunces',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Shopify handles signup securely in the browser.',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 25),
                          _SignupField(
                            hint: 'First name',
                            icon: Icons.person,
                            controller: _firstNameController,
                          ),
                          const SizedBox(height: 13),
                          _SignupField(
                            hint: 'Last name',
                            icon: Icons.person,
                            controller: _lastNameController,
                          ),
                          const SizedBox(height: 13),
                          _SignupField(
                            hint: 'Mobile number',
                            icon: Icons.dialpad,
                            keyboardType: TextInputType.phone,
                            controller: _phoneController,
                            phoneField: true,
                          ),
                          const SizedBox(height: 13),
                          _SignupField(
                            hint: 'Email address',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            controller: _emailController,
                            emailField: true,
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : _signupWithShopify,
                              style: FilledButton.styleFrom(
                                backgroundColor: _brown,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _brown.withValues(
                                  alpha: .55,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                size: 25,
                              ),
                              label: Text(
                                _submitting
                                    ? 'Opening Shopify...'
                                    : 'Signup with Shopify',
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xff5e514b),
                              ),
                              child: const Text(
                                'Already have an account? Login',
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
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

class _SignupField extends StatelessWidget {
  const _SignupField({
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.controller,
    this.emailField = false,
    this.phoneField = false,
  });

  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final bool emailField;
  final bool phoneField;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: emailField ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xfffff9f0),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xffa6a09d), fontSize: 12),
        prefixIcon: Icon(icon, color: _SignupScreenState._brown, size: 26),
        prefixIconConstraints: const BoxConstraints(minWidth: 56),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _SignupScreenState._brown,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: _SignupScreenState._brown,
            width: 1.7,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.7),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return '$hint is required';
        if (emailField &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Enter a valid email address';
        }
        if (phoneField && !RegExp(r'^\d{10,15}$').hasMatch(text)) {
          return 'Enter a valid mobile number';
        }
        if (!emailField && !phoneField && text.length < 2) {
          return '$hint is too short';
        }
        return null;
      },
    );
  }
}
