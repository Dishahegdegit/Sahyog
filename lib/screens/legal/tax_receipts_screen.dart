import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class TaxReceiptsScreen extends StatelessWidget {
  const TaxReceiptsScreen({super.key});

  Future<void> _generatePdfReceipt(BuildContext context, String donorName, String donationId, String foodType, int servings) async {
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
                      pw.Text('SAHYOG FOOD REDISTRIBUTION NETWORK', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('80G TAX DEDUCTION CERTIFICATE', style: pw.TextStyle(fontSize: 12, color: PdfColors.orange900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Certificate No: 80G/SAHYOG/2026/$donationId'),
                pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('This is to certify that $donorName has contributed in-kind surplus food donations to verified NGO partners through Sahyog.'),
                pw.SizedBox(height: 12),
                pw.Bullet(text: 'Donation ID: #SH-$donationId'),
                pw.Bullet(text: 'Category: $foodType'),
                pw.Bullet(text: 'Estimated Servings Shared: $servings Meals'),
                pw.SizedBox(height: 24),
                pw.Text('Tax Exemption Status: Eligible for 80G Tax Benefits under Section 80G of the Income Tax Act.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Authorized Signatory'),
                      pw.Text('Sahyog Foundation Trust'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sahyog_80G_Receipt_$donationId.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('80G Tax Exemption Receipts', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? Center(child: Text('Please log in to view tax receipts.', style: TextStyle(color: c.textPrimary)))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('donorId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final status = (doc.data()['status'] ?? '').toString().toLowerCase();
                  return status == 'completed' || status == 'delivered';
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text('No Completed Tax Receipts Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                          const SizedBox(height: 8),
                          Text('Receipts generate automatically when donations are marked delivered by NGOs.', style: TextStyle(color: c.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final foodType = data['foodType'] ?? 'Veg';
                    final servings = data['servings'] is int ? data['servings'] as int : 0;
                    final donorName = user.displayName ?? 'Valued Donor';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('80G Receipt #${doc.id.substring(0, 6).toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary)),
                              const SizedBox(height: 4),
                              Text('$foodType • $servings Meals Impacted', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: const Text('Download PDF'),
                            onPressed: () => _generatePdfReceipt(context, donorName, doc.id, foodType, servings),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
