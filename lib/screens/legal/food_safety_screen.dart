import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class FoodSafetyScreen extends StatelessWidget {
  const FoodSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Food Safety Standards', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    'Sahyog Food Hygiene & Safety Protocol',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text('FSSAI Compliant Governance Guidelines', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  Divider(color: c.borderLight, height: 32),

                  const Text('1. Preparation Hygiene', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Food must be prepared in sanitized, clean kitchens by personnel wearing hairnets and disposable gloves. Surfaces must be sanitized prior to cooking.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('2. Temperature Control & Shelf Life', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Cooked meals must be kept above 60°C or refrigerated below 5°C. Hot meals must be dispatched to recipient NGOs within 4 hours of preparation.',
                    style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text('3. Packaging & Sealing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(
                    'Containers must be food-grade, tamper-evident, and sealed to prevent spillages or external contamination during transport.',
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
