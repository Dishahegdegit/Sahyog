import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../constants/ngo_theme.dart';
import '../../models/ngo/donation_model.dart';
import 'pickup_details_screen.dart';

class NgoMapScreen extends StatefulWidget {
  const NgoMapScreen({super.key});

  @override
  State<NgoMapScreen> createState() => _NgoMapScreenState();
}

class _NgoMapScreenState extends State<NgoMapScreen> {
  NgoTheme get t => NgoTheme.of(context);
  String get _currentNgoId => FirebaseAuth.instance.currentUser?.uid ?? 'ngo_demo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            // Map header / Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(color: t.surfaceContainerHighest, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: t.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Pickup Locations Map',
                    style: GoogleFonts.publicSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Top map card (mocking interactive map screen)
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  // Stylized map background
                  Container(
                    width: double.infinity,
                    color: t.surfaceContainerHigh,
                    child: StreamBuilder<List<DonationModel>>(
                      stream: FirebaseFirestore.instance
                          .collection('donations')
                          .snapshots()
                          .map((snap) => snap.docs
                              .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
                              .where((d) =>
                                  d.acceptedByNgoId == _currentNgoId &&
                                  (d.status == 'Accepted' ||
                                      d.status == 'Volunteer Assigned' ||
                                      d.status == 'Picked Up'))
                              .toList()),
                      builder: (context, snapshot) {
                        final activePickups = snapshot.data ?? [];
                        return CustomPaint(
                          size: Size.infinite,
                          painter: InteractiveMapPainter(activePickups: activePickups, isDark: t.isDark),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Live Pickup Tracking',
                        style: GoogleFonts.publicSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // In-Progress Pickups list title
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Active In-Progress Pickups',
                style: GoogleFonts.publicSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ),

            // List of In-Progress Pickups
            Expanded(
              flex: 5,
              child: StreamBuilder<List<DonationModel>>(
                stream: FirebaseFirestore.instance
                    .collection('donations')
                    .snapshots()
                    .map((snap) => snap.docs
                        .map((doc) => DonationModel.fromMap(doc.data(), doc.id))
                        .where((d) =>
                            d.acceptedByNgoId == _currentNgoId &&
                            (d.status == 'Accepted' ||
                                d.status == 'Volunteer Assigned' ||
                                d.status == 'Picked Up'))
                        .toList()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }

                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final donation = list[index];
                      return _buildActivePickupCard(donation);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePickupCard(DonationModel donation) {
    Color statusColor;
    switch (donation.status) {
      case 'Volunteer Assigned':
        statusColor = t.tertiary;
        break;
      case 'Picked Up':
        statusColor = t.secondary;
        break;
      default:
        statusColor = t.primary;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.surfaceContainerHighest),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PickupDetailsScreen(donationId: donation.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Left: Info & Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.foodTitle,
                      style: GoogleFonts.publicSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Donor: ${donation.donorName}',
                      style: GoogleFonts.publicSans(
                        fontSize: 12,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: t.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            donation.pickupLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (donation.assignedVolunteerName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.motorcycle, size: 14, color: t.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'Volunteer: ${donation.assignedVolunteerName}',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Right: Status Badge & Chevron
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      donation.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(Icons.chevron_right, color: t.outline, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surfaceContainerLow,
              ),
              child: Icon(Icons.local_shipping_outlined, size: 30, color: t.outline),
            ),
            const SizedBox(height: 12),
            Text(
              'No In-Progress Pickups',
              style: GoogleFonts.publicSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available food collections will appear here once accepted and volunteers are assigned.',
              textAlign: TextAlign.center,
              style: GoogleFonts.publicSans(
                fontSize: 12,
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw roads & location pins on the Map background
class InteractiveMapPainter extends CustomPainter {
  final List<DonationModel> activePickups;
  final bool isDark;
  InteractiveMapPainter({required this.activePickups, this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Background Grid
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Road paths
    final roadPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final roadCenterPaint = Paint()
      ..color = isDark ? const Color(0xFF333537) : AppColors.surfaceContainerHighest
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Grid roads
    path.moveTo(0, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.3);

    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width, size.height * 0.7);

    path.moveTo(size.width * 0.25, 0);
    path.lineTo(size.width * 0.25, size.height);

    path.moveTo(size.width * 0.75, 0);
    path.lineTo(size.width * 0.75, size.height);

    // Curve road connecting
    path.moveTo(size.width * 0.25, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.5, size.width * 0.75, size.height * 0.7);

    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path, roadCenterPaint);

    // Draw Pinpoints for NGO and active pickups
    final ngoPinPaint = Paint()..color = isDark ? AppColors.darkSecondary : AppColors.secondary;
    // NGO Hub location (say, center of map)
    final ngoCenter = Offset(size.width * 0.5, size.height * 0.45);
    canvas.drawCircle(ngoCenter, 10, ngoPinPaint);
    canvas.drawCircle(ngoCenter, 16, ngoPinPaint..style = PaintingStyle.stroke..strokeWidth = 2.0);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw active pickups locations
    int i = 0;
    for (var pickup in activePickups) {
      i++;
      // Determine a pseudo coordinate based on ID to make it deterministic
      final int hash = pickup.id.hashCode;
      final double offsetFactorX = (hash % 10) / 10.0;
      final double offsetFactorY = ((hash ~/ 10) % 10) / 10.0;

      final double px = 50 + (size.width - 100) * offsetFactorX;
      final double py = 50 + (size.height - 100) * offsetFactorY;
      final offset = Offset(px, py);

      // Draw donor location orange/red pin
      final pinPaint = Paint()..color = isDark ? AppColors.darkPrimary : AppColors.primary;
      canvas.drawCircle(offset, 8, pinPaint);

      // Draw route line to NGO center
      final routePaint = Paint()
        ..color = (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: 0.5)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(offset, ngoCenter, routePaint);

      // Text label "1", "2"...
      textPainter.text = TextSpan(
        text: i.toString(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
