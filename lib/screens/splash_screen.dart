import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'auth/login_screen.dart';
import 'donor/donor_home.dart';
import 'ngo/ngo_home.dart';
import 'admin/admin_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Check auth after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), _checkAuth);
  }

  Future<void> _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not logged in → go to Login
      _navigate(const LoginScreen());
      return;
    }

    // Logged in → get role from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = doc.data()?['role'] ?? 'donor';

    // Navigate based on role
    switch (role) {
      case 'admin':
        _navigate(const AdminHome());
        break;
      case 'ngo':
        _navigate(const NgoHome());
        break;
      default:
        _navigate(const DonorHome());
    }
  }

  void _navigate(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.volunteer_activism,
                        size: 70,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // App Name
                    const Text(
                      'Sahyog',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Connecting Food to Those in Need',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.85),
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Loading indicator
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.7),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}