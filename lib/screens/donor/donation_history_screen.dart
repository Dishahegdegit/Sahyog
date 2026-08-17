import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../constants/app_colors.dart';
import '../../models/donor/donation_model.dart';
import 'donation_detail_screen.dart';
import '../legal/tax_receipts_screen.dart';

class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  String _selectedFilter = 'All'; // 'All' | 'Pending' | 'Accepted' | 'In Transit' | 'Delivered' | 'Cancelled'
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterChips = [
    'All',
    'Pending',
    'Accepted',
    'In Transit',
    'Delivered',
    'Completed',
    'Cancelled',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted by ngo':
      case 'accepted':
        return AppColors.statusAccepted;
      case 'volunteer assigned':
      case 'in transit':
      case 'picked up':
        return AppColors.statusTransit;
      case 'delivered':
      case 'completed':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'pending':
      default:
        return AppColors.statusPending;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  Future<void> _generatePdfReport(BuildContext context, String donorName, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SAHYOG DONATION AUDIT SUMMARY', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('CONFIDENTIAL AUDIT REPORT', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text('Donor Name: $donorName'),
                pw.Text('Total Donations Recorded: ${docs.length}'),
                pw.Text('Report Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    <String>['Donation ID', 'Food Type', 'Quantity / Servings', 'Status', 'NGO Partner'],
                    ...docs.map((d) {
                      final map = d.data();
                      return [
                        '#SH-${d.id.substring(0, d.id.length > 5 ? 5 : d.id.length).toUpperCase()}',
                        map['foodType'] ?? 'Veg',
                        '${map['servings'] ?? 0} Servings',
                        (map['status'] ?? 'Pending').toString().toUpperCase(),
                        map['ngoName'] ?? 'Unassigned',
                      ];
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sahyog_Donation_History_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Text('Please log in to view your donation history.', style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Universal Top App Bar
                  _buildTopAppBar(user),
                  const SizedBox(height: 24),

                  // Header Title Section
                  const Text(
                    'Donation History & Audit Trail',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Complete dynamic record of your food contributions, partner NGO receipts, and impact receipts.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by Donation ID or Food Type...',
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterChips.map((chip) {
                        final isSelected = _selectedFilter == chip;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(chip),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.borderLight,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = chip;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Real Firestore Stream
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('donations')
                        .where('donorId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Error loading donation history: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        );
                      }

                      final allDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                        snapshot.data?.docs ?? [],
                      );

                      // Calculate Analytics Summary
                      int totalCount = allDocs.length;
                      int totalMealsDonated = 0;
                      int acceptedCount = 0;

                      for (var doc in allDocs) {
                        final d = doc.data();
                        final s = d['servings'];
                        final servings = s is int ? s : int.tryParse(s?.toString() ?? '0') ?? 0;
                        final statusStr = (d['status'] ?? '').toString().toLowerCase();

                        if (statusStr == 'completed' || statusStr == 'delivered' || statusStr.contains('accepted')) {
                          totalMealsDonated += servings;
                          acceptedCount++;
                        }
                      }
                      double acceptanceRate = totalCount > 0 ? (acceptedCount / totalCount) * 100 : 0;

                      // Filter records based on selected chip and search term
                      final searchQuery = _searchController.text.trim().toLowerCase();
                      final filteredDocs = allDocs.where((doc) {
                        final data = doc.data();
                        final statusStr = (data['status'] ?? '').toString().toLowerCase();
                        final foodType = (data['foodType'] ?? '').toString().toLowerCase();
                        final docId = doc.id.toLowerCase();

                        // Search matching
                        bool matchesSearch = searchQuery.isEmpty ||
                            foodType.contains(searchQuery) ||
                            docId.contains(searchQuery);

                        // Chip matching
                        bool matchesFilter = true;
                        if (_selectedFilter != 'All') {
                          final targetFilter = _selectedFilter.toLowerCase();
                          matchesFilter = statusStr.contains(targetFilter);
                        }

                        return matchesSearch && matchesFilter;
                      }).toList();

                      filteredDocs.sort((a, b) {
                        final aTime = a.data()['createdAt'];
                        final bTime = b.data()['createdAt'];
                        if (aTime is Timestamp && bTime is Timestamp) {
                          return bTime.compareTo(aTime);
                        }
                        return 0;
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Analytics Summary Strip
                          _buildAnalyticsStrip(totalCount, totalMealsDonated, acceptanceRate),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Audit Trail Records',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: const Text('Download History (PDF)'),
                                onPressed: () {
                                  _generatePdfReport(context, user.displayName ?? 'Valued Donor', filteredDocs);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (filteredDocs.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.history_rounded, size: 54, color: AppColors.primary),
                                  SizedBox(height: 16),
                                  Text(
                                    'No donation history records found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Accepted NGO requests and completed donations will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final docData = filteredDocs[index].data();
                                final docId = filteredDocs[index].id;
                                final donation = DonationModel.fromMap(docData, docId);
                                final ngoName = docData['ngoName'] as String? ?? 'Not Assigned';
                                final statusColor = _getStatusColor(donation.status);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.borderLight),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color.fromRGBO(0, 0, 0, 0.03),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DonationDetailScreen(
                                            donationId: docId,
                                          ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryTint,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(
                                                      Icons.restaurant,
                                                      size: 20,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    donation.foodType,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: statusColor),
                                                ),
                                                child: Text(
                                                  donation.status.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildDetailTile(
                                                  Icons.scale_outlined,
                                                  'Quantity',
                                                  donation.foodQuantity.isEmpty ? 'N/A' : donation.foodQuantity,
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildDetailTile(
                                                  Icons.people_outline,
                                                  'People Served',
                                                  '~${donation.servings}',
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildDetailTile(
                                                  Icons.business_outlined,
                                                  'NGO Partner',
                                                  ngoName,
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildDetailTile(
                                                  Icons.calendar_today_outlined,
                                                  'Donation Date',
                                                  _formatDate(donation.createdAt),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(color: AppColors.borderLight, height: 24),

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () {
                                                   Navigator.push(context, MaterialPageRoute(builder: (context) => const TaxReceiptsScreen()));
                                                 },
                                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
                                                label: const Text(
                                                  'Tax Receipt (80G PDF)',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                ),
                                              ),
                                              Row(
                                                children: const [
                                                  Text(
                                                    'View Details',
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Icon(
                                                    Icons.chevron_right,
                                                    size: 18,
                                                    color: AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsStrip(int totalCount, int totalMeals, double acceptanceRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAnalyticsItem('Total Submissions', '$totalCount'),
          Container(width: 1, height: 30, color: AppColors.borderLight),
          _buildAnalyticsItem('Meals Impacted', '$totalMeals'),
          Container(width: 1, height: 30, color: AppColors.borderLight),
          _buildAnalyticsItem('Acceptance Rate', '${acceptanceRate.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTopAppBar(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('donors').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        String profileUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileUrl = snapshot.data!.data()?['profileImageUrl'] ?? '';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sahyog',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                      child: profileUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
