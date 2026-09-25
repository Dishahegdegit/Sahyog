import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  Future<void> _generatePdfReport(BuildContext context, String title) async {
    final pdf = pw.Document();
    final db = FirebaseFirestore.instance;

    // Fetch data based on report type
    List<List<String>> tableData = [];
    String reportHeading = '';

    // Helper functions for safe parsing & date formatting
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is DateTime) return val;
      return null;
    }

    String formatDate(dynamic val, String pattern, [String fallback = '']) {
      final dt = parseDate(val);
      return dt != null ? DateFormat(pattern).format(dt) : fallback;
    }

    try {
      if (title == 'Daily Donations') {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final snap = await db.collection('donations').get();
        reportHeading = 'Daily Donations Report - ${DateFormat('dd MMM yyyy').format(now)}';
        tableData.add(['Food Type', 'Quantity', 'Donor', 'Status', 'Time']);
        for (var doc in snap.docs) {
          final d = doc.data();
          final dt = parseDate(d['createdAt']);
          if (dt != null && dt.isAfter(startOfDay)) {
            tableData.add([
              (d['foodTitle'] ?? d['foodName'] ?? d['foodType'] ?? '').toString(),
              (d['foodQuantity'] ?? d['quantity'] ?? d['servings'] ?? '').toString(),
              (d['donorName'] ?? 'Unknown').toString(),
              (d['status'] ?? 'pending').toString(),
              formatDate(d['createdAt'], 'HH:mm'),
            ]);
          }
        }
      } else if (title == 'Monthly Donations') {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final snap = await db.collection('donations').get();
        reportHeading = 'Monthly Donations Report - ${DateFormat('MMMM yyyy').format(now)}';
        tableData.add(['Date', 'Food Type', 'Servings', 'NGO', 'Status']);
        for (var doc in snap.docs) {
          final d = doc.data();
          final dt = parseDate(d['createdAt']);
          if (dt == null || dt.isAfter(startOfMonth)) {
            tableData.add([
              formatDate(d['createdAt'], 'dd MMM'),
              (d['foodTitle'] ?? d['foodName'] ?? d['foodType'] ?? '').toString(),
              (d['servings'] ?? d['foodQuantity'] ?? '0').toString(),
              (d['ngoName'] ?? 'Pending').toString(),
              (d['status'] ?? 'pending').toString(),
            ]);
          }
        }
      } else if (title == 'NGO Performance') {
        final ngosSnap = await db.collection('users').where('role', isEqualTo: 'ngo').get();
        final donationsSnap = await db.collection('donations').get();
        
        reportHeading = 'NGO Efficiency & Distribution Performance';
        tableData.add(['NGO Name', 'Received', 'Completed', 'Reg ID', 'Efficiency']);
        
        for (var doc in ngosSnap.docs) {
          final d = doc.data();
          final ngoId = doc.id;
          final ngoName = (d['name'] ?? d['organizationName'] ?? 'NGO').toString();
          
          final received = donationsSnap.docs.where((don) => don.data()['ngoId'] == ngoId).length;
          final completed = donationsSnap.docs.where((don) {
            final st = (don.data()['status'] ?? '').toString().toLowerCase();
            return don.data()['ngoId'] == ngoId && (st == 'completed' || st == 'delivered');
          }).length;
          
          final efficiency = received > 0 ? '${((completed / received) * 100).toStringAsFixed(0)}%' : '0%';
          
          tableData.add([
            ngoName,
            received.toString(),
            completed.toString(),
            (d['registrationId'] ?? d['regId'] ?? 'N/A').toString(),
            efficiency
          ]);
        }
      } else if (title == 'Food Distribution Reports') {
        final snap = await db.collection('donations').get();
        reportHeading = 'Complete Food Distribution Log';
        tableData.add(['Donor', 'NGO', 'Volunteer', 'Address', 'Quantity']);
        for (var doc in snap.docs) {
          final d = doc.data();
          final st = (d['status'] ?? '').toString().toLowerCase();
          if (st == 'completed' || st == 'delivered') {
            tableData.add([
              (d['donorName'] ?? 'Donor').toString(),
              (d['ngoName'] ?? 'NGO').toString(),
              (d['assignedVolunteerName'] ?? d['volunteerName'] ?? 'Volunteer').toString(),
              (d['pickupAddress'] ?? d['address'] ?? 'N/A').toString(),
              (d['foodQuantity'] ?? d['servings'] ?? 'N/A').toString(),
            ]);
          }
        }
      } else if (title == 'Volunteer Activity') {
        final snap = await db.collection('volunteers').get();
        reportHeading = 'Volunteer Performance & Activity';
        tableData.add(['Volunteer Name', 'Status', 'Vehicle Type', 'Deliveries', 'Joined']);
        for (var doc in snap.docs) {
          final d = doc.data();
          tableData.add([
            (d['name'] ?? 'Unknown').toString(),
            (d['status'] ?? 'Available').toString(),
            (d['vehicleType'] ?? d['vehicle'] ?? 'N/A').toString(),
            (d['completedDeliveries'] ?? d['deliveriesCount'] ?? 0).toString(),
            formatDate(d['createdAt'], 'dd/MM/yy', 'N/A'),
          ]);
        }
      } else if (title == 'Beneficiary Statistics') {
        final snap = await db.collection('donations').get();
        reportHeading = 'Platform Beneficiary Statistics';
        tableData.add(['Month', 'Completed Deliveries', 'Total Servings', 'Food Distributed (kg)']);
        
        // Aggregation by month for completed donations
        Map<String, List<int>> monthlyStats = {};
        for (var doc in snap.docs) {
          final d = doc.data();
          final st = (d['status'] ?? '').toString().toLowerCase();
          if (st == 'completed' || st == 'delivered') {
            final date = parseDate(d['createdAt']) ?? DateTime.now();
            final monthKey = DateFormat('MMM yyyy').format(date);
            final servings = d['servings'] is num
                ? (d['servings'] as num).toInt()
                : (int.tryParse(d['servings']?.toString() ?? '0') ?? 0);
            
            if (!monthlyStats.containsKey(monthKey)) {
              monthlyStats[monthKey] = [0, 0, 0];
            }
            monthlyStats[monthKey]![0] += 1;
            monthlyStats[monthKey]![1] += servings;
          }
        }

        if (monthlyStats.isEmpty) {
          final currentMonth = DateFormat('MMM yyyy').format(DateTime.now());
          tableData.add([currentMonth, '0', '0', '0.0 kg']);
        } else {
          monthlyStats.forEach((key, val) {
            tableData.add([key, val[0].toString(), val[1].toString(), '${(val[1] * 0.4).toStringAsFixed(1)} kg']);
          });
        }
      } else {
        // Generic fallback for other reports
        reportHeading = '$title Summary';
        tableData.add(['Metric', 'Value']);
        final users = await db.collection('users').get();
        final donations = await db.collection('donations').get();
        tableData.add(['Total Users', users.docs.length.toString()]);
        tableData.add(['Total Donations', donations.docs.length.toString()]);
      }

      // Split table: first row is headers, rest is data
      final headers = tableData.isNotEmpty ? tableData.first : <String>[];
      final rows = tableData.length > 1 ? tableData.sublist(1) : <List<String>>[];
      final generatedAt = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
      final orangeColor = PdfColor.fromHex('#FF6B35');
      final orangeLight = PdfColor.fromHex('#FFF3EE');
      final greyText = PdfColor.fromHex('#6B7280');
      final darkText = PdfColor.fromHex('#111827');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          header: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Orange gradient header band
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [orangeColor, PdfColor.fromHex('#FF8C5A')],
                      begin: pw.Alignment.centerLeft,
                      end: pw.Alignment.centerRight,
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SAHYOG',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 3,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Admin Panel Report',
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: PdfColor.fromHex('#FFE0D5'),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            title,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#FFE0D5')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Sub-header with report name and date
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  color: orangeLight,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        reportHeading,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: orangeColor,
                        ),
                      ),
                      pw.Text(
                        'Generated: $generatedAt',
                        style: pw.TextStyle(fontSize: 10, color: greyText),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            );
          },
          footer: (pw.Context ctx) {
            return pw.Column(
              children: [
                pw.Divider(color: PdfColor.fromHex('#E5E7EB'), thickness: 0.5),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '© Sahyog Admin Panel',
                        style: pw.TextStyle(fontSize: 9, color: greyText),
                      ),
                      pw.Text(
                        'Generated on $generatedAt',
                        style: pw.TextStyle(fontSize: 9, color: greyText),
                      ),
                      pw.Text(
                        'Page ${ctx.pageNumber}',
                        style: pw.TextStyle(fontSize: 9, color: greyText),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          build: (pw.Context ctx) {
            return [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 36),
                child: rows.isEmpty
                    ? pw.Center(
                        child: pw.Text('No data available for this report.',
                            style: pw.TextStyle(color: greyText, fontSize: 13)),
                      )
                    : pw.TableHelper.fromTextArray(
                        headers: headers,
                        data: rows,
                        border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
                        headerDecoration: pw.BoxDecoration(color: orangeLight),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: orangeColor,
                        ),
                        cellStyle: pw.TextStyle(fontSize: 10, color: darkText),
                        cellHeight: 28,
                        rowDecoration: const pw.BoxDecoration(),
                        oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FAFAFA')),
                        cellAlignments: {for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft},
                      ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final List<Map<String, dynamic>> reports = [
      {'title': 'Daily Donations', 'icon': Icons.calendar_today, 'desc': 'Summary of all donations made today.'},
      {'title': 'Monthly Donations', 'icon': Icons.calendar_month, 'desc': 'Aggregated donation statistics for the month.'},
      {'title': 'NGO Performance', 'icon': Icons.business, 'desc': 'Metrics on NGO distributions and efficiency.'},
      {'title': 'Food Distribution Reports', 'icon': Icons.restaurant, 'desc': 'Detailed logs of all food distributions.'},
      {'title': 'Volunteer Activity', 'icon': Icons.directions_walk, 'desc': 'Logs of volunteer pickups and deliveries.'},
      {'title': 'Beneficiary Statistics', 'icon': Icons.people, 'desc': 'Data on people served by the NGOs.'},
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Reports',
                style: GoogleFonts.publicSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a report type to download as a PDF.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: reports.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            report['icon'] as IconData,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          report['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            report['desc'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
                          onPressed: () => _generatePdfReport(context, report['title'] as String),
                          tooltip: 'Download PDF',
                        ),
                      ),
                    ),
                  );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

