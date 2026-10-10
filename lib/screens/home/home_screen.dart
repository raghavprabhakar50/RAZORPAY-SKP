import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({this.guest = false, super.key});

  final bool guest;

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
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/skp logo 2.png',
                  width: 190,
                  height: 190,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  guest ? 'Welcome, Guest' : 'Welcome to Sri Krishna Pearls',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff7d4d39),
                    fontFamily: 'Fraunces',
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Home screen'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
