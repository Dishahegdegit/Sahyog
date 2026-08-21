import 'package:flutter/material.dart';

/// Shared breakpoints so web stays wide while phone/emulator layouts compact.
class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
}

class Responsive {
  Responsive._(this.width);

  factory Responsive.of(BuildContext context) {
    return Responsive._(MediaQuery.sizeOf(context).width);
  }

  final double width;

  bool get isCompact => width < AppBreakpoints.compact;
  bool get isMedium => width >= AppBreakpoints.compact && width < AppBreakpoints.medium;
  bool get isExpanded => width >= AppBreakpoints.medium;

  double get pagePadding => isCompact ? 14.0 : (isMedium ? 20.0 : 28.0);

  double get sectionGap => isCompact ? 16.0 : 24.0;

  double get cardPadding => isCompact ? 14.0 : 20.0;

  double get heroTitleSize => isCompact ? 22.0 : 28.0;

  double get pageTitleSize => isCompact ? 22.0 : 26.0;

  double get sectionTitleSize => isCompact ? 16.0 : 18.0;

  double get carouselHeight {
    if (width < 380) return 160;
    if (isCompact) return 180;
    if (isMedium) return 200;
    return 220;
  }

  double get contentMaxWidth {
    if (isCompact) return double.infinity;
    if (isMedium) return 900;
    return 1200;
  }

  double get formMaxWidth {
    if (isCompact) return double.infinity;
    return 800;
  }

  /// Horizontal inset for sticky orange headers.
  double get headerPadding {
    if (width >= 1100) return 32;
    if (width >= 700) return 24;
    return 16;
  }
}

/// Stack children vertically on phones; keep a row on wider layouts.
class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 12,
    this.breakpoint = AppBreakpoints.compact,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final double breakpoint;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < breakpoint;
    if (narrow) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            SizedBox(width: double.infinity, child: children[i]),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
