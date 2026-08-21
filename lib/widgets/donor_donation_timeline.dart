import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/donation_tracking.dart';

class DonorDonationTimeline extends StatelessWidget {
  const DonorDonationTimeline({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cancelled = DonationTracking.isCancelled(status);
    final current = DonationTracking.stepIndex(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        children: [
          if (cancelled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: AppColors.statusCancelled, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'This donation was cancelled',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusCancelled,
                    ),
                  ),
                ],
              ),
            ),
          ...List.generate(DonationTracking.steps.length, (index) {
            final isLast = index == DonationTracking.steps.length - 1;
            final reached = !cancelled && current >= index;
            final isCurrent = !cancelled && current == index;
            return _TimelineStep(
              title: DonationTracking.steps[index],
              isReached: reached,
              isCurrent: isCurrent,
              isLast: isLast,
              muted: cancelled,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.isReached,
    required this.isCurrent,
    required this.isLast,
    required this.muted,
  });

  final String title;
  final bool isReached;
  final bool isCurrent;
  final bool isLast;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color nodeColor = muted
        ? c.outlineVariant
        : (isReached ? AppColors.primary : c.outlineVariant);
    final Color textColor = muted
        ? c.textSecondary
        : (isReached ? c.textPrimary : c.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isReached && !muted ? AppColors.primary : Colors.transparent,
                border: Border.all(color: nodeColor, width: 2),
              ),
              child: isReached && !muted
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isReached && !muted ? AppColors.primary : c.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 8 : 18, top: 2),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent || isReached ? FontWeight.w800 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
