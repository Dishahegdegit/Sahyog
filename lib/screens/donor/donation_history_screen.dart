import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/donor/donation_model.dart';
import '../../utils/responsive.dart';
import '../../utils/donation_tracking.dart';
import '../../widgets/donor_notification_bell.dart';
import '../../utils/page_limits.dart';
import 'donation_detail_screen.dart';
import '../legal/tax_receipts_screen.dart';

class DonationHistoryScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const DonationHistoryScreen({super.key, this.onTabChange});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  String _selectedFilter = 'All';
  String _selectedFoodType = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  int _pageLimit = PageLimits.pageSize;

  final List<String> _filterChips = [
    'All',
    'Pending',
    'Accepted',
    'In Transit',
    'Delivered',
    'Completed',
    'Cancelled',
  ];

  final List<String> _foodTypeChips = ['All', 'Veg', 'Non-Veg'];

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickFilterDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        _toDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  bool _matchesStatusFilter(String statusStr) {
    if (_selectedFilter == 'All') return true;
    final target = _selectedFilter.toLowerCase();
    if (target == 'in transit') {
      return statusStr.contains('transit') ||
          statusStr.contains('picked') ||
          statusStr.contains('volunteer');
    }
    if (target == 'pending') {
      return statusStr.contains('pending') || statusStr.contains('submitted');
    }
    return statusStr.contains(target);
  }

  DateTime? _createdAt(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Color _getStatusColor(String status) => DonationTracking.statusColor(status);

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
    final c = context.colors;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: Center(
          child: Text('Please log in to view your donation history.', style: TextStyle(color: c.textPrimary)),
        ),
      );
    }

    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(user),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: r.pagePadding, vertical: 16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Title Section
                        Text(
                    r.isCompact ? 'Donation History' : 'Donation History & Audit Trail',
                    style: TextStyle(
                      fontSize: r.pageTitleSize,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.isCompact
                        ? 'Your food contributions, NGO receipts, and impact records.'
                        : 'Complete dynamic record of your food contributions, partner NGO receipts, and impact receipts.',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                  ),
                  SizedBox(height: r.sectionGap),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search food, NGO, donation ID...',
                      hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: c.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.borderLight),
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
                            backgroundColor: c.surface,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : c.borderLight,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : c.textPrimary,
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
                  const SizedBox(height: 12),

                  Text(
                    'Food Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _foodTypeChips.map((chip) {
                        final isSelected = _selectedFoodType == chip;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(chip == 'All' ? 'All types' : chip),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: c.surface,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : c.borderLight,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : c.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedFoodType = chip);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _locationController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Filter by pickup location...',
                      hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      suffixIcon: _locationController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: c.textSecondary),
                              onPressed: () {
                                _locationController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickFilterDate(isFrom: true),
                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                          label: Text(
                            _fromDate == null ? 'From date' : DateFormat('dd MMM yyyy').format(_fromDate!),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textPrimary,
                            side: BorderSide(color: c.borderLight),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickFilterDate(isFrom: false),
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(
                            _toDate == null ? 'To date' : DateFormat('dd MMM yyyy').format(_toDate!),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textPrimary,
                            side: BorderSide(color: c.borderLight),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          ),
                        ),
                      ),
                      if (_fromDate != null || _toDate != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Clear dates',
                          onPressed: () => setState(() {
                            _fromDate = null;
                            _toDate = null;
                          }),
                          icon: Icon(Icons.close, color: c.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Real Firestore Stream
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('donations')
                        .where('donorId', isEqualTo: user.uid)
                        .limit(_pageLimit)
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
                      final locationQuery = _locationController.text.trim().toLowerCase();
                      final filteredDocs = allDocs.where((doc) {
                        final data = doc.data();
                        final statusStr = (data['status'] ?? '').toString().toLowerCase();
                        final foodType = (data['foodType'] ?? '').toString().toLowerCase();
                        final foodName = (data['foodName'] ?? data['foodTitle'] ?? '').toString().toLowerCase();
                        final ngoName = (data['ngoName'] ?? data['acceptedByNgoName'] ?? '').toString().toLowerCase();
                        final volunteer = (data['assignedVolunteerName'] ?? data['volunteerName'] ?? '').toString().toLowerCase();
                        final address = (data['pickupAddress'] ?? data['pickupLocation'] ?? '').toString().toLowerCase();
                        final docId = doc.id.toLowerCase();
                        final created = _createdAt(data['createdAt']);

                        final matchesSearch = searchQuery.isEmpty ||
                            foodType.contains(searchQuery) ||
                            foodName.contains(searchQuery) ||
                            ngoName.contains(searchQuery) ||
                            volunteer.contains(searchQuery) ||
                            address.contains(searchQuery) ||
                            docId.contains(searchQuery);

                        final matchesFoodType = _selectedFoodType == 'All' ||
                            foodType == _selectedFoodType.toLowerCase();

                        final matchesLocation = locationQuery.isEmpty || address.contains(locationQuery);

                        bool matchesDate = true;
                        if (_fromDate != null) {
                          matchesDate = created != null && !created.isBefore(_fromDate!);
                        }
                        if (matchesDate && _toDate != null) {
                          matchesDate = created != null && !created.isAfter(_toDate!);
                        }

                        return matchesSearch &&
                            _matchesStatusFilter(statusStr) &&
                            matchesFoodType &&
                            matchesLocation &&
                            matchesDate;
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

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stack = constraints.maxWidth < 420;
                              final title = Text(
                                'Audit Trail Records',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                              );
                              final pdfButton = ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                icon: const Icon(Icons.picture_as_pdf, size: 18),
                                label: Text(stack ? 'PDF' : 'Download History (PDF)'),
                                onPressed: () {
                                  _generatePdfReport(context, user.displayName ?? 'Valued Donor', filteredDocs);
                                },
                              );

                              if (stack) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    title,
                                    const SizedBox(height: 10),
                                    SizedBox(width: double.infinity, child: pdfButton),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: title),
                                  pdfButton,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          if (filteredDocs.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: c.borderLight),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded, size: 54, color: AppColors.primary),
                                  SizedBox(height: 16),
                                  Text(
                                    'No donation history records found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Accepted NGO requests and completed donations will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
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
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: c.borderLight),
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Row(
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
                                                    Expanded(
                                                      child: Text(
                                                        donation.foodName.trim().isNotEmpty
                                                            ? donation.foodName
                                                            : donation.foodType,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: c.textPrimary,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: statusColor),
                                                ),
                                                child: Text(
                                                  DonationTracking.displayLabel(donation.status).toUpperCase(),
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

                                          ResponsiveRow(
                                            spacing: 12,
                                            breakpoint: 380,
                                            children: [
                                              _buildDetailTile(
                                                Icons.scale_outlined,
                                                'Quantity',
                                                donation.foodQuantity.isEmpty ? 'N/A' : donation.foodQuantity,
                                              ),
                                              _buildDetailTile(
                                                Icons.people_outline,
                                                'People Served',
                                                '~${donation.servings}',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          ResponsiveRow(
                                            spacing: 12,
                                            breakpoint: 380,
                                            children: [
                                              _buildDetailTile(
                                                Icons.business_outlined,
                                                'NGO Partner',
                                                ngoName,
                                              ),
                                              _buildDetailTile(
                                                Icons.calendar_today_outlined,
                                                'Donation Date',
                                                _formatDate(donation.createdAt),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ResponsiveRow(
                                            spacing: 12,
                                            breakpoint: 380,
                                            children: [
                                              _buildDetailTile(
                                                Icons.local_shipping_outlined,
                                                'Pickup Status',
                                                DonationTracking.pickupStatus(donation.status),
                                              ),
                                              _buildDetailTile(
                                                Icons.volunteer_activism_outlined,
                                                'Delivery Status',
                                                DonationTracking.deliveryStatus(donation.status),
                                              ),
                                            ],
                                          ),
                                          Divider(color: c.borderLight, height: 24),

                                          Wrap(
                                            alignment: WrapAlignment.spaceBetween,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () {
                                                   Navigator.push(context, MaterialPageRoute(builder: (context) => const TaxReceiptsScreen()));
                                                 },
                                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
                                                label: Text(
                                                  'Tax Receipt (80G PDF)',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                ),
                                              ),
                                              const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
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
                                                    Icons.arrow_forward_ios,
                                                    size: 12,
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
                            LoadMoreBar(
                              visibleCount: allDocs.length,
                              limit: _pageLimit,
                              onLoadMore: () => setState(() => _pageLimit += PageLimits.pageSize),
                            ),
                              ],
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
    ],
  ),
),
);
  }

  Widget _buildAnalyticsStrip(int totalCount, int totalMeals, double acceptanceRate) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          Expanded(child: _buildAnalyticsItem('Total Submissions', '$totalCount')),
          Container(width: 1, height: 30, color: c.borderLight),
          Expanded(child: _buildAnalyticsItem('Meals Impacted', '$totalMeals')),
          Container(width: 1, height: 30, color: c.borderLight),
          Expanded(child: _buildAnalyticsItem('Acceptance Rate', '${acceptanceRate.toStringAsFixed(0)}%')),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String title, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: c.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
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
                      Text(
                        'Sahyog',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const DonorNotificationBell(size: 24),
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onTabChange?.call(4),
                        child: Container(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
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
