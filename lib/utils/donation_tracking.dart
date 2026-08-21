import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Spec path: Submitted → Accepted → Volunteer Assigned → Picked Up → Delivered → Completed
class DonationTracking {
  static const List<String> steps = [
    'Submitted',
    'Accepted',
    'Volunteer Assigned',
    'Picked Up',
    'Delivered',
    'Completed',
  ];

  static String normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty || value == 'pending' || value == 'submitted' || value == 'available') {
      return 'submitted';
    }
    if (value.contains('cancel')) return 'cancelled';
    if (value.contains('complete')) return 'completed';
    if (value.contains('deliver')) return 'delivered';
    if (value.contains('picked') || value.contains('transit')) return 'picked_up';
    if (value.contains('volunteer') || value.contains('assigned')) return 'volunteer_assigned';
    if (value.contains('accept')) return 'accepted';
    return 'submitted';
  }

  static bool isCancelled(String? raw) => normalize(raw) == 'cancelled';

  /// 0..5 for the spec path. Cancelled stays at last reached-looking submitted unless we treat as -1.
  static int stepIndex(String? raw) {
    switch (normalize(raw)) {
      case 'accepted':
        return 1;
      case 'volunteer_assigned':
        return 2;
      case 'picked_up':
        return 3;
      case 'delivered':
        return 4;
      case 'completed':
        return 5;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }

  static String displayLabel(String? raw) {
    if (isCancelled(raw)) return 'Cancelled';
    return steps[stepIndex(raw).clamp(0, steps.length - 1)];
  }

  static Color statusColor(String? raw) {
    switch (normalize(raw)) {
      case 'accepted':
        return AppColors.statusAccepted;
      case 'volunteer_assigned':
      case 'picked_up':
        return AppColors.statusTransit;
      case 'delivered':
      case 'completed':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.statusPending;
    }
  }

  static String pickupStatus(String? raw) {
    switch (normalize(raw)) {
      case 'cancelled':
        return 'Cancelled';
      case 'picked_up':
      case 'delivered':
      case 'completed':
        return 'Picked up';
      case 'volunteer_assigned':
        return 'Volunteer assigned';
      case 'accepted':
        return 'Awaiting pickup';
      default:
        return 'Not started';
    }
  }

  static String deliveryStatus(String? raw) {
    switch (normalize(raw)) {
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'delivered':
        return 'Delivered';
      case 'picked_up':
        return 'In transit';
      default:
        return 'Pending delivery';
    }
  }

  static Color pickupColor(String? raw) {
    switch (normalize(raw)) {
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'picked_up':
      case 'delivered':
      case 'completed':
        return AppColors.statusDelivered;
      case 'volunteer_assigned':
      case 'accepted':
        return AppColors.statusTransit;
      default:
        return AppColors.statusPending;
    }
  }

  static Color deliveryColor(String? raw) {
    switch (normalize(raw)) {
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'completed':
      case 'delivered':
        return AppColors.statusDelivered;
      case 'picked_up':
        return AppColors.statusTransit;
      default:
        return AppColors.statusPending;
    }
  }
}
