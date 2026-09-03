import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD54F), // Yellow background
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Logo
            Image.asset(
              'assets/logo/logo.png',
              height: 170,
            ),

            const SizedBox(height: 25),

            // Institute Name
            const Text(
              "OMEGA",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
                letterSpacing: 2,
              ),
            ),

            const Text(
              "EDUCATION CENTRE",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "An Amazing Teaching Style",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),

            const Spacer(),

            const CircularProgressIndicator(
              color: Color(0xFF0D47A1),
            ),

            const SizedBox(height: 15),

            const Text(
              "Loading...",
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}