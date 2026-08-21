import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.borderLight),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.03), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sahyog Platform Terms of Service',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text('Version 2.4 • Effective Date: August 2026', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Divider(color: c.borderLight, height: 32),

                  const Text('1. Overview & Mission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Sahyog connects surplus food donors with registered non-governmental organizations (NGOs) and community relief teams. By accessing or using the Sahyog platform, donors agree to act with standard food safety practices and honesty.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('2. Food Safety & Integrity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Donors warrant that all food offered is freshly prepared, wholesome, and stored under sanitary conditions. Food must not be contaminated, expired, or spoiled.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('3. Commercial Use Prohibition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Food items donated on Sahyog are strictly non-commercial. Neither donors nor receiving NGOs shall sell, barter, or trade donated food for monetary consideration.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('4. Pickup Logistics & Governance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Donors must prepare meals in leak-proof packaging prior to the agreed pickup window. Registered volunteer drivers will verify quality before transit.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
