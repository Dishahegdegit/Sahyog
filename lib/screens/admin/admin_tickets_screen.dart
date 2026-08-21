import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../models/admin/ticket_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_limits.dart';
import '../donor/donation_detail_screen.dart';

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  String _status = 'open';
  int _limit = PageLimits.pageSize;

  Future<void> _updateStatus(TicketModel ticket, String status) async {
    await FirebaseFirestore.instance.collection('tickets').doc(ticket.id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reply(TicketModel ticket) async {
    final controller = TextEditingController(text: ticket.adminReply ?? '');
    final colors = context.colors;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Reply to ticket', style: GoogleFonts.publicSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Admin note or resolution...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await FirebaseFirestore.instance.collection('tickets').doc(ticket.id).update({
        'adminReply': controller.text.trim(),
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('tickets')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (_status != 'all') {
      query = FirebaseFirestore.instance
          .collection('tickets')
          .where('status', isEqualTo: _status)
          .limit(_limit);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Issue tickets',
              style: GoogleFonts.publicSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open, track, and resolve donor/NGO reports',
              style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['open', 'in_progress', 'resolved', 'all'].map((chip) {
                final selected = _status == chip;
                return ChoiceChip(
                  label: Text(chip.replaceAll('_', ' ')),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = chip),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('No tickets in this view.', style: TextStyle(color: colors.textSecondary)),
              )
            else
              ...docs.map((doc) {
                final ticket = TicketModel.fromMap(doc.data(), doc.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.subject,
                              style: GoogleFonts.publicSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            ticket.status.replaceAll('_', ' '),
                            style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ticket.description,
                        style: GoogleFonts.inter(fontSize: 13, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ticket.creatorName} · ${ticket.creatorRole}'
                        '${ticket.createdAt != null ? ' · ${DateFormat('dd MMM, hh:mm a').format(ticket.createdAt!)}' : ''}',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                      if (ticket.adminReply != null && ticket.adminReply!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Admin: ${ticket.adminReply}', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _reply(ticket),
                            child: const Text('Reply'),
                          ),
                          if (ticket.status != 'resolved')
                            TextButton(
                              onPressed: () => _updateStatus(ticket, 'resolved'),
                              child: const Text('Resolve'),
                            ),
                          if (ticket.donationId != null && ticket.donationId!.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DonationDetailScreen(donationId: ticket.donationId!),
                                  ),
                                );
                              },
                              child: const Text('Donation'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            LoadMoreBar(
              visibleCount: docs.length,
              limit: _limit,
              onLoadMore: () => setState(() => _limit += PageLimits.pageSize),
            ),
          ],
        );
      },
    );
  }
}
