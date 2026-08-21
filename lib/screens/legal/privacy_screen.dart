import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    'Sahyog Data Privacy & Security Policy',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text('Updated: August 2026', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Divider(color: c.borderLight, height: 32),

                  const Text('1. Information Collection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'We collect donor name, contact number, pickup address, and food condition images strictly for fulfilling donation logistics.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('2. Data Usage & Sharing Scope', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Contact details and address pins are shared exclusively with verified pickup drivers and assigned recipient NGOs. We do not sell or monetize personal information.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('3. Cloud Storage Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'All images and user records are stored securely using encrypted cloud channels (Firebase & Cloudinary SSL).',
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
