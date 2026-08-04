import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/onboarding_screen.dart';
import '../constants/app_colors.dart';
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
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 3000), _checkAuth);
  }

  Future<void> _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _navigate(const OnboardingScreen());
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = doc.data()?['role'] ?? 'donor';

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
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, animation, __) => FadeTransition(opacity: animation, child: screen),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Dynamic theme-based colors
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.background;
    final emblemBgColor = isDark ? const Color(0xFF1E2022) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtitleColor = isDark ? const Color(0xFFC7A58E) : AppColors.textSecondary;
    final loaderTrackColor = isDark ? const Color(0xFF282A2C) : AppColors.surfaceContainerLow;
    final shadowColor = isDark ? const Color(0xFFFFB59D) : AppColors.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background Mandala & Glow Painter
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: PremiumMandalaPainter(
                    pulse: _pulseAnimation.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // Central Content
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),

                        // Emblem Icon inside radial ring
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: emblemBgColor,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(isDark ? 0.6 : 0.4),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(isDark ? 0.3 : 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            size: 38,
                            color: AppColors.primary,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Brand Title: S A H Y O G
                        Text(
                          'S A H Y O G',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: 12,
                            shadows: [
                              Shadow(
                                color: shadowColor.withOpacity(isDark ? 0.5 : 0.25),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Thin accent line
                        Container(
                          width: 48,
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary.withOpacity(isDark ? 0.8 : 0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Subtitle
                        Text(
                          'C O L L A B O R A T I O N   F O R\nC O M M U N I T Y   I M P A C T',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.publicSans(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                            letterSpacing: 2.5,
                            height: 1.8,
                          ),
                        ),

                        const Spacer(flex: 3),

                        // Bottom Initializing indicator with animated orange loading line
                        Column(
                          children: [
                            SizedBox(
                              width: 100,
                              height: 2,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  backgroundColor: loaderTrackColor,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'I N I T I A L I Z I N G',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary.withOpacity(0.9),
                                letterSpacing: 4.0,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to generate the glowing gold radial ring and organic floral lotus petal pattern
class PremiumMandalaPainter extends CustomPainter {
  final double pulse;
  final bool isDark;

  PremiumMandalaPainter({required this.pulse, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);

    // 1. Radial Glow Halo
    final glowPaint = Paint()
      ..shader = RadialGradient(
          colors: [
            isDark
                ? const Color(0xFFC49100).withOpacity(0.24 * pulse)
                : const Color(0xFFC49100).withOpacity(0.08 * pulse),
            isDark
                ? const Color(0xFFFF6B35).withOpacity(0.14 * pulse)
                : const Color(0xFFFF6B35).withOpacity(0.05 * pulse),
            Colors.transparent,
          ],
          stops: const [0.15, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: minDim * 0.75));

    canvas.drawCircle(center, minDim * 0.65 * pulse, glowPaint);

    // 2. Floral Petals Paints
    final petalColor = isDark 
        ? const Color(0xFFD4AF37).withOpacity(0.28) 
        : const Color(0xFFFF6B35).withOpacity(0.12);
    final outerPetalColor = isDark 
        ? const Color(0xFFC49100).withOpacity(0.18) 
        : const Color(0xFF2E6B68).withOpacity(0.08); // Sage teal details for contrast in light mode
    final innerCircleColor = isDark 
        ? const Color(0xFFD4AF37).withOpacity(0.20) 
        : const Color(0xFFFF6B35).withOpacity(0.10);

    final petalPaint = Paint()
      ..color = petalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final outerPetalPaint = Paint()
      ..color = outerPetalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final innerCirclePaint = Paint()
      ..color = innerCircleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final baseRadius = minDim * 0.38 * pulse;

    // Draw inner concentric ring
    canvas.drawCircle(center, baseRadius * 0.85, innerCirclePaint);
    canvas.drawCircle(center, baseRadius * 1.15, innerCirclePaint);

    // Draw Inner Layer of Organic Floral Lotus Petals (16 Petals)
    const int petalCount = 16;
    for (int i = 0; i < petalCount; i++) {
      final angle = (i * 2 * math.pi) / petalCount;
      final nextAngle = ((i + 1) * 2 * math.pi) / petalCount;
      final midAngle = (angle + nextAngle) / 2;

      final p1 = Offset(
        center.dx + baseRadius * math.cos(angle),
        center.dy + baseRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + baseRadius * math.cos(nextAngle),
        center.dy + baseRadius * math.sin(nextAngle),
      );

      // Petal Tip extending outwards
      final tip = Offset(
        center.dx + (baseRadius * 1.45) * math.cos(midAngle),
        center.dy + (baseRadius * 1.45) * math.sin(midAngle),
      );

      // Curved floral petal path
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(
          center.dx + (baseRadius * 1.35) * math.cos(angle + 0.1),
          center.dy + (baseRadius * 1.35) * math.sin(angle + 0.1),
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          center.dx + (baseRadius * 1.35) * math.cos(nextAngle - 0.1),
          center.dy + (baseRadius * 1.35) * math.sin(nextAngle - 0.1),
          p2.dx,
          p2.dy,
        );

      canvas.drawPath(path, petalPaint);
    }

    // Draw Outer Layer of Intersecting Floral Arc Petals (24 Petals)
    const int outerPetalCount = 24;
    final outerRadius = baseRadius * 1.2;
    for (int i = 0; i < outerPetalCount; i++) {
      final angle = (i * 2 * math.pi) / outerPetalCount;
      final nextAngle = ((i + 1) * 2 * math.pi) / outerPetalCount;
      final midAngle = (angle + nextAngle) / 2;

      final p1 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(nextAngle),
        center.dy + outerRadius * math.sin(nextAngle),
      );

      final tip = Offset(
        center.dx + (outerRadius * 1.38) * math.cos(midAngle),
        center.dy + (outerRadius * 1.38) * math.sin(midAngle),
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(
          center.dx + (outerRadius * 1.25) * math.cos(midAngle),
          center.dy + (outerRadius * 1.25) * math.sin(midAngle),
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          center.dx + (outerRadius * 1.25) * math.cos(midAngle),
          center.dy + (outerRadius * 1.25) * math.sin(midAngle),
          p2.dx,
          p2.dy,
        );

      canvas.drawPath(path, outerPetalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PremiumMandalaPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}