import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/ticket_service.dart';

class SupportFaqScreen extends StatelessWidget {
  const SupportFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Support & Help Center', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.borderLight),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.headset_mic_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('24/7 Sahyog Dispatch Helpline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary)),
                            const SizedBox(height: 4),
                            const Text('+91 1800-SAHYOG • support@sahyog.org', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openTicketDialog(context),
                    icon: const Icon(Icons.report_gmailerrorred_outlined),
                    label: const Text('Open an issue ticket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text('Frequently Asked Questions (FAQ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const SizedBox(height: 12),

                _buildFaqItem(c, 'How do NGOs get assigned to my donation?', 'When you submit a request with "Auto-Assign", our system matches the request with verified NGOs within your geographic proximity.'),
                _buildFaqItem(c, 'Can I cancel a donation request?', 'Yes! You can cancel any pending donation directly from your Active Dispatch Tracker or Donation Details screen before an NGO accepts it.'),
                _buildFaqItem(c, 'How is food quality verified?', 'Our verified volunteer drivers inspect packaging and check preparation timestamps before loading food into transit.'),
                _buildFaqItem(c, 'How do I download my 80G tax receipt?', 'Once an NGO marks your donation as Delivered/Completed, navigate to the 80G Tax Exemption tab from the 3-dot menu or profile screen to download your PDF receipt.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTicketDialog(BuildContext context) async {
    final subject = TextEditingController();
    final details = TextEditingController();
    final c = context.colors;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Open an issue ticket', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 12),
            TextField(
              controller: details,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Describe the issue'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) return;
    try {
      await TicketService.createTicket(
        subject: subject.text.trim().isEmpty ? 'Support request' : subject.text.trim(),
        description: details.text.trim().isEmpty ? 'No details provided.' : details.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket submitted. An admin will follow up.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit ticket: $e')));
      }
    }
  }

  Widget _buildFaqItem(AppColorSet c, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight),
      ),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          title: Text(question, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.textPrimary)),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(answer, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}
