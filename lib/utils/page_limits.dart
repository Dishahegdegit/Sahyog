import 'package:flutter/material.dart';

class PageLimits {
  static const int pageSize = 20;
}

class LoadMoreBar extends StatelessWidget {
  const LoadMoreBar({
    super.key,
    required this.visibleCount,
    required this.limit,
    required this.onLoadMore,
  });

  final int visibleCount;
  final int limit;
  final VoidCallback onLoadMore;

  bool get canLoadMore => visibleCount >= limit;

  @override
  Widget build(BuildContext context) {
    if (!canLoadMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: OutlinedButton(
        onPressed: onLoadMore,
        child: const Text('Load more'),
      ),
    );
  }
}
